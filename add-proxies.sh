sudo cp /etc/environment /etc/environment.$(date +%Y%m%d%H%M%S).bak && \
sudo awk 'BEGIN{insert_after=2; n=0}
{lines[++n]=$0}
END{
  for(i=1;i<=n;i++){
    if(i==insert_after){ # print current line, then block
      print lines[i]
      print "ALL_PROXY=\"socks5h://anuragsinha.duckdns.org:1080\""
      print "HTTP_PROXY=\"socks5h://anuragsinha.duckdns.org:1080\""
      print "HTTPS_PROXY=\"socks5h://anuragsinha.duckdns.org:1080\""
      print "FTP_PROXY=\"socks5h://anuragsinha.duckdns.org:1080\""
      print "RSYNC_PROXY=\"socks5h://anuragsinha.duckdns.org:1080\""
      print "no_proxy=\"localhost,127.0.0.1\""
      continue
    }
    # skip existing proxy lines
    if (lines[i] ~ /^(ALL_PROXY|HTTP_PROXY|HTTPS_PROXY|FTP_PROXY|RSYNC_PROXY|no_proxy)=/) next
    print lines[i]
  }
}' /etc/environment | sudo tee /etc/environment >/dev/null
