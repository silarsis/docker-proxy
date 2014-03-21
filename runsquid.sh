#!/bin/bash

# Setup the NAT rule that enables transparent proxying
IPADDR=$(/sbin/ifconfig eth0 | grep 'inet addr' | awk 'BEGIN { FS = "[ :]+" } ; { print $4 }')
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination ${IPADDR}:3128

# Make sure our cache is setup
chown proxy.proxy /var/spool/squid3
[ -e /var/spool/squid3/swap.state ] || squid3 -z 2>/dev/null

# Run squid and tail the logs
squid3
while true; do
  [ -e /var/log/squid3/access.log ] && tail -f /var/log/squid3/access.log
  sleep 1
done
