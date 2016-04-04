#!/bin/bash

# If the host is running a web proxy, use it for apt.
# Adapted from https://gist.github.com/dergachev/8441335

APT_PROXY_PORT=$1
PROXY_LAUNCHPAD=${2:-no}

HOST_IP=$(route -n | awk '/^0.0.0.0/ {print $2}')
nc -z "$HOST_IP" ${APT_PROXY_PORT}

if [ $? -eq 0 ]; then
    echo "Acquire::http::Proxy \"http://$HOST_IP:$APT_PROXY_PORT\";" >> /etc/apt/apt.conf.d/30proxy
    if [ "$PROXY_LAUNCHPAD" = yes ]; then
        echo "Acquire::http::Proxy::ppa.launchpad.net DIRECT;" >> /etc/apt/apt.conf.d/30proxy
    fi
    echo "Using host's apt proxy"
else
    echo "No apt proxy detected on Docker host"
fi
