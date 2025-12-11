#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./add-proxies.sh [--dry-run] [--no-backup] [--after N] [--file /path/to/file]
#
# Examples:
#   ./add-proxies.sh           # perform change on /etc/environment (asks for sudo if needed)
#   ./add-proxies.sh --dry-run # show what would change
#   ./add-proxies.sh --after 3 --file ./test.env

DRY_RUN=0
MAKE_BACKUP=1
INSERT_AFTER=2
TARGET_FILE="/etc/environment"

while (( "$#" )); do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --no-backup) MAKE_BACKUP=0; shift ;;
    --after) INSERT_AFTER="$2"; shift 2 ;;
    --file) TARGET_FILE="$2"; shift 2 ;;
    -h|--help) sed -n '1,200p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ "$INSERT_AFTER" =~ ^[0-9]+$ ]] || { echo "insert-after must be a number"; exit 1; }

# Proxy block to insert
read -r -d '' PROXY_BLOCK <<'EOF' || true
ALL_PROXY="socks5h://anuragsinha.duckdns.org:1080"
HTTP_PROXY="socks5h://anuragsinha.duckdns.org:1080"
HTTPS_PROXY="socks5h://anuragsinha.duckdns.org:1080"
FTP_PROXY="socks5h://anuragsinha.duckdns.org:1080"
RSYNC_PROXY="socks5h://anuragsinha.duckdns.org:1080"
no_proxy="localhost,127.0.0.1"
EOF

# sanity
if [[ ! -e "$TARGET_FILE" ]]; then
  echo "Target file $TARGET_FILE does not exist. Will create it (but a backup won't be made)." >&2
fi

TS=$(date +%Y%m%d%H%M%S)
if [[ $MAKE_BACKUP -eq 1 && -e "$TARGET_FILE" ]]; then
  BACKUP_PATH="${TARGET_FILE}.${TS}.bak"
  echo "Creating backup: $BACKUP_PATH"
  if [[ -w "$TARGET_FILE" ]]; then
    cp -- "$TARGET_FILE" "$BACKUP_PATH"
  else
    sudo cp -- "$TARGET_FILE" "$BACKUP_PATH"
  fi
fi

# Create a cleaned version (remove existing proxy variable lines)
CLEANED="$(mktemp)"
# Remove lines starting with these variable names exactly (case-sensitive)
grep -v -E '^(ALL_PROXY|HTTP_PROXY|HTTPS_PROXY|FTP_PROXY|RSYNC_PROXY|no_proxy)=' "${TARGET_FILE:-/dev/null}" 2>/dev/null > "$CLEANED" || true

# If the file didn't exist, ensure cleaned file exists
: >"$CLEANED"  # ensure cleaned file exists (makes it empty if previously non-existent)

# Build the final file by inserting block after INSERT_AFTER. If file has fewer lines, append.
FINAL="$(mktemp)"
TOTAL_LINES=$(wc -l < "$CLEANED" || echo 0)
if (( TOTAL_LINES < INSERT_AFTER )); then
  # copy entire cleaned file then block
  cat "$CLEANED" > "$FINAL"
  printf '%s\n' "$PROXY_BLOCK" >> "$FINAL"
else
  # head, then block, then tail
  head -n "$INSERT_AFTER" "$CLEANED" > "$FINAL"
  printf '%s\n' "$PROXY_BLOCK" >> "$FINAL"
  tail -n +"$((INSERT_AFTER + 1))" "$CLEANED" >> "$FINAL"
fi

# show result if dry run
if [[ $DRY_RUN -eq 1 ]]; then
  echo "===== Original (cleaned) file content ====="
  cat "$CLEANED"
  echo
  echo "===== Proposed final content ====="
  cat "$FINAL"
  echo
  echo "===== Unified diff ====="
  # if target file exists show diff between target and final (taking into account cleaned removal)
  if [[ -e "$TARGET_FILE" ]]; then
    if command -v diff >/dev/null 2>&1; then
      diff -u "$TARGET_FILE" "$FINAL" || true
    else
      echo "(diff not available)"
    fi
  else
    echo "(target file does not exist; final will be created)"
    cat "$FINAL"
  fi
  # cleanup
  rm -f "$CLEANED" "$FINAL"
  exit 0
fi

# Move final into place (use sudo if necessary)
echo "Writing changes to $TARGET_FILE"
if [[ -w "$TARGET_FILE" || ! -e "$TARGET_FILE" ]]; then
  mv "$FINAL" "$TARGET_FILE"
else
  sudo mv "$FINAL" "$TARGET_FILE"
fi

# tidy
rm -f "$CLEANED"

echo "Done. If you created a backup it is at: ${BACKUP_PATH:-(none)}"
echo "You may want to log out and back in (or source /etc/environment) for changes to take effect."
