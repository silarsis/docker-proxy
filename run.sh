#!/bin/bash
#
# Script to maintain ip rules on the host when starting up a transparent
# proxy server for docker.

CACHEDIR="/tmp/squid3" # Change this to place the cache somewhere else

set -e

# Guard for my own scripts
# Note, if you're running this script direct, it will rebuild if it can't see
# the image.
[ -z ${RUNNING_DRUN} ] && {
  RUN_DOCKER="docker run"
  CONTAINER_NAME='proxy'
  docker images | grep "^${CONTAINER_NAME} " >/dev/null || docker build -q --rm -t ${CONTAINER_NAME} .
}

start_routing () {
  # Add a new route table that routes everything marked through the new container
  grep TRANSPROXY /etc/iproute2/rt_tables >/dev/null || \
    sudo bash -c "echo '1	TRANSPROXY' >> /etc/iproute2/rt_tables"
  ip rule show | grep TRANSPROXY >/dev/null || \
    sudo ip rule add from all fwmark 0x1 lookup TRANSPROXY
  sudo ip route add default via ${IPADDR} dev docker0 table TRANSPROXY
  # Mark packets to port 80 external, so they route through the new route table
  sudo iptables -t mangle -I PREROUTING -p tcp --dport 80 \! -s ${IPADDR} -i docker0 -j MARK --set-mark 1
  # Exemption rule to stop docker from masquerading traffic routed to the
  # transparent proxy
  sudo iptables -t nat -I POSTROUTING -o docker0 -s 172.17.0.0/16 -j ACCEPT
}

stop_routing () {
  # Remove the appropriate rules - that is, those that mention the IP Address.
  set +e
  [ "x$IPADDR" != "x" ] && {
    ip route show table TRANSPROXY | grep default >/dev/null && \
      sudo ip route del default table TRANSPROXY
    sudo iptables -t mangle -L PREROUTING | grep 'tcp dpt:80 MARK set 0x1' >/dev/null && \
      sudo iptables -t mangle -D PREROUTING -p tcp --dport 80 \! -s ${IPADDR} -i docker0 -j MARK --set-mark 1
    sudo iptables -t nat -D POSTROUTING -o docker0 -s 172.17.0.0/16 -j ACCEPT 2>/dev/null
  }
  set -e
}

stop () {
  # Ideally we'd leave the container around and re-use it, but I really
  # need a nice way to query for a named container first. Doesn't cost much
  # to create a new container anyway, especially given the cache volume is mapped.
  set +e
  docker kill ${CONTAINER_NAME} >/dev/null 2>&1
  docker rm ${CONTAINER_NAME} >/dev/null 2>&1
  set -e
  stop_routing
}

run () {
  # Make sure we have a cache dir - if you're running in vbox you should
  # probably map this through to the host machine for persistence
  mkdir -p "${CACHEDIR}"
  # Because we're named, make sure the container doesn't already exist
  stop
  # Run and find the IP for the running container
  CID=$(${RUN_DOCKER} --privileged -d -v "${CACHEDIR}":/var/spool/squid3 --name ${CONTAINER_NAME} ${CONTAINER_NAME})
  IPADDR=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${CID})
  start_routing
  # Run at console, kill cleanly if ctrl-c is hit
  trap stop SIGINT
  echo 'Now entering wait, please hit "ctrl-c" to kill proxy and undo routing'
  echo "'docker logs -f ${CID}' if you wish to view the access logs in real time"
  docker wait ${CID}
  stop
}

# Guard so I can include  this script into my own scripts
[ -z ${RUNNING_DRUN} ] && run
echo
