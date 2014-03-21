#!/bin/bash

set -e

# http://stackoverflow.com/questions/10775863/best-way-to-check-if-a-iptables-userchain-exist
chain_exists ()
{
    [ $# -lt 1 -o $# -gt 2 ] && {
        echo "Usage: chain_exists <chain_name> [table]" >&2
        return 1
    }
    local chain_name="$1" ; shift
    [ $# -eq 1 ] && local table="--table $1"
    iptables $table -n --list "$chain_name" >/dev/null 2>&1
}

start_routing () {
  grep TRANSPROXY /etc/iproute2/rt_tables >/dev/null || \
    echo "1	TRANSPROXY" >> /etc/iproute2/rt_tables
  ip rule show | grep TRANSPROXY >/dev/null || \
    ip rule add from all fwmark 0x1 lookup TRANSPROXY
  ip route add default via ${IPADDR} dev docker0 table TRANSPROXY
  iptables -t mangle -I PREROUTING -p tcp --dport 80 \! -s ${IPADDR} -i docker0 -j MARK --set-mark 1
  iptables -t nat -I POSTROUTING -o docker0 -s 172.17.0.0/16 -j ACCEPT
}

stop_routing () {
  set +e
  [ "x$IPADDR" != "x" ] && {
    ip route show table TRANSPROXY | grep default >/dev/null && \
      ip route del default via ${IPADDR} dev docker0 table TRANSPROXY
    iptables -t mangle -L PREROUTING | grep ${IPADDR} >/dev/null && \
      iptables -t mangle -D PREROUTING -p tcp --dport 80 \! -s ${IPADDR} -i docker0 -j MARK --set-mark 1
    iptables -t nat -D POSTROUTING -o docker0 -s 172.17.0.0/16 -j ACCEPT 2>/dev/null
  }
  set -e
}

stop () {
  # Ideally we'd leave the container around and re-use it, but I really
  # need a nice way to query for a named container first
  set +e
  docker kill squid >/dev/null 2>&1
  docker rm squid >/dev/null 2>&1
  set -e
  stop_routing
}

run () {
  # Make sure we have a cache dir - if you're running in vbox you should
  # probably map this through to the host machine for persistence
  mkdir -p /tmp/squid-cache && chown nobody.nogroup /tmp/squid-cache
  # Because we're named, make sure the container doesn't already exist
  stop
  # Run and find the IP for the running container
  CID=$(docker run --privileged -d -p 3128:3128 -v /tmp/squid-cache:/var/spool/squid3 --name squid squid)
  IPADDR=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${CID})
  start_routing
  # Run at console, kill cleanly if ctrl-c is hit
  trap stop SIGINT
  docker wait squid
  stop
}
