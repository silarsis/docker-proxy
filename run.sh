#!/bin/bash
#
# Script to maintain ip rules on the host when starting up a transparent
# proxy server for docker.

CACHEDIR=${CACHEDIR:-/var/lib/docker-proxy/cache}
CERTDIR=${CERTDIR:-/var/lib/docker-proxy/ssl}
CONTAINER_NAME=${CONTAINER_NAME:-docker-proxy}
if [ "$1" = 'ssl' ]; then
    WITH_SSL=yes
else
    WITH_SSL=no
fi

set -e

sudo docker images | grep -q "^${CONTAINER_NAME} " \
    || (echo "Build ${CONTAINER_NAME} image first" && exit 1)

start_routing () {
  # Add a new route table that routes everything marked through the new container
  # workaround boot2docker issue #367
  # https://github.com/boot2docker/boot2docker/issues/367
  [ -d /etc/iproute2 ] || sudo mkdir -p /etc/iproute2
  if [ ! -e /etc/iproute2/rt_tables ]; then
    if [ -f /usr/local/etc/rt_tables ]; then
      sudo ln -s /usr/local/etc/rt_tables /etc/iproute2/rt_tables
    elif [ -f /usr/local/etc/iproute2/rt_tables ]; then
      sudo ln -s /usr/local/etc/iproute2/rt_tables /etc/iproute2/rt_tables
    fi
  fi
  ([ -e /etc/iproute2/rt_tables ] && grep -q TRANSPROXY /etc/iproute2/rt_tables) \
    || sudo sh -c "echo '1	TRANSPROXY' >> /etc/iproute2/rt_tables"
  ip rule show | grep -q TRANSPROXY \
    || sudo ip rule add from all fwmark 0x1 lookup TRANSPROXY
  sudo ip route add default via "${IPADDR}" dev docker0 table TRANSPROXY
  # Mark packets to port 80 and 443 external, so they route through the new
  # route table
  COMMON_RULES="-t mangle -I PREROUTING -p tcp -i docker0 ! -s ${IPADDR}
    -j MARK --set-mark 1"
  echo "Redirecting HTTP to docker-proxy"
  sudo iptables $COMMON_RULES --dport 80
  if [ "$WITH_SSL" = 'yes' ]; then
      echo "Redirecting HTTPS to docker-proxy"
      sudo iptables $COMMON_RULES --dport 443
  else
      echo "Not redirecting HTTPS. To enable, re-run with the argument 'ssl'"
      echo "CA certificate will be generated anyway, but it won't be used"
  fi
  # Exemption rule to stop docker from masquerading traffic routed to the
  # transparent proxy
  sudo iptables -t nat -I POSTROUTING -o docker0 -s 172.17.0.0/16 -j ACCEPT
}

stop_routing () {
    # Remove iptables rules.
    set +e
    ip route show table TRANSPROXY | grep -q default \
        && sudo ip route del default table TRANSPROXY
    while true; do
        rule_num=$(sudo iptables -t mangle -L PREROUTING -n --line-numbers \
            | grep -E 'MARK.*172\.17.*tcp \S+ MARK set 0x1' \
            | awk '{print $1}' \
            | head -n1)
        [ -z "$rule_num" ] && break
        sudo iptables -t mangle -D PREROUTING "$rule_num"
    done
    sudo iptables -t nat -D POSTROUTING -o docker0 -s 172.17.0.0/16 -j ACCEPT 2>/dev/null
    set -e
}

stop () {
  set +e
  sudo docker rm -fv ${CONTAINER_NAME} >/dev/null 2>&1
  set -e
  stop_routing
}

interrupted () {
  echo 'Interrupted, cleaning up...'
  trap - INT
  stop
  kill -INT $$
}

terminated () {
  echo 'Terminated, cleaning up...'
  trap - TERM
  stop
  kill -TERM $$
}

run () {
  # Make sure we have a cache dir - if you're running in vbox you should
  # probably map this through to the host machine for persistence
  mkdir -p "${CACHEDIR}" "${CERTDIR}"
  # Because we're named, make sure the container doesn't already exist
  stop
  # Run and find the IP for the running container. Bind the forward proxy port
  # so clients can get the CA certificate.
  CID=$(sudo docker run --privileged -d \
        --name ${CONTAINER_NAME} \
        --volume="${CACHEDIR}":/var/spool/squid3 \
        --volume="${CERTDIR}":/etc/squid3/ssl_cert \
        --publish=3128:3128 \
        ${CONTAINER_NAME})
  IPADDR=$(sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${CID})
  start_routing
  # Run at console, kill cleanly if ctrl-c is hit
  trap interrupted INT
  trap terminated TERM
  echo 'Now entering wait, please hit "ctrl-c" to kill proxy and undo routing'
  sudo docker logs -f "${CID}"
  echo 'Squid exited unexpectedly, cleaning up...'
  stop
}

run
echo
