#!/bin/bash

function gen-cert() {
    pushd /etc/squid3/ssl_cert > /dev/null
    if [ ! -f ca.pem ]; then
        openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes \
            -x509 -keyout privkey.pem -out ca.pem \
            -subj '/CN=docker-proxy/O=NULL/C=AU'
        chown proxy.proxy privkey.pem
        chmod 600 privkey.pem
        openssl x509 -in ca.pem -outform DER -out ca.der
    else
        echo "Reusing existing certificate"
    fi
    openssl x509 -sha1 -in ca.pem -noout -fingerprint
    # Make CA certificate available for download via HTTP Forwarding port
    # e.g. GET http://docker-proxy:3128/squid-internal-static/icons/ca.pem
    cp `pwd`/ca.* /usr/share/squid3/icons/
    popd > /dev/null
    return $?
}

function start-routing() {
    # Setup the NAT rule that enables transparent proxying
    IPADDR=$(/sbin/ip -o -f inet addr show eth0 | awk '{ sub(/\/.+/,"",$4); print $4 }')
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination ${IPADDR}:3129
    iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination ${IPADDR}:3130
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

squid3
tail -f /var/log/squid3/access.log /var/log/squid3/cache.log
