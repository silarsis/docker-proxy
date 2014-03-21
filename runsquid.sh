#!/bin/bash

echo "Getting IP"
IPADDR=$(/sbin/ifconfig eth0 | grep 'inet addr' | awk 'BEGIN { FS = "[ :]+" } ; { print $4 }')
echo "IP Address is ${IPADDR}, setting up DNAT"
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination ${IPADDR}:3128

echo "Chown"
chown proxy.proxy /var/spool/squid3
echo "Building cache directories"
squid3 -z 2>/dev/null
echo "Executing Squid"
squid3 -N -d 1
echo "Completed"
