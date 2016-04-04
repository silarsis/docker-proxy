#!/bin/bash

function gen-cert() {
    cd /etc/squid3/ssl_cert
    openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 \
        -keyout myCA.pem -out myCA.pem \
        -subj '/CN=squid-ssl/O=NULL/C=AU'
    chmod 600 myCA.pem
    openssl x509 -in myCA.pem -outform DER -out myCA.der
    chown proxy.proxy myCA.pem
    return $?
}

function start-routing() {
    # Setup the NAT rule that enables transparent proxying
    IPADDR=$(/sbin/ip -o -f inet addr show eth0 | awk '{ sub(/\/.+/,"",$4); print $4 }')
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination ${IPADDR}:3128
    return $?
}

function init-cache() {
    # Make sure our cache is setup
    touch /var/log/squid3/access.log /var/log/squid3/cache.log
    chown proxy.proxy -R /var/spool/squid3 /var/log/squid3
    [ -e /var/spool/squid3/swap.state ] || squid3 -z 2>/dev/null
}

gen-cert || exit 1
start-routing || exit 1
init-cache

echo starting server

# Run squid and tail the logs
squid3
sleep 0.5
ps aux
tail -f /var/log/squid3/access.log /var/log/squid3/cache.log
