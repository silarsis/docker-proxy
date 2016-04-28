#!/bin/bash

function download-cert() {
    # The proxy server hosts the root certificate over HTTP, on a port that is
    # published on the host.
    AWK_SPLIT='
        !fout && /^\r?$/ { fout="docker-proxy.pem"; next }
        fout { print > fout }
        !fout { print }
    '

    HOST_IP=$(route -n | awk '/^0.0.0.0/ {print $2}')
    echo -e 'GET /squid-internal-static/icons/ca.pem\r\n' \
        | nc -q -1 "$HOST_IP" 3128 \
        | awk "$AWK_SPLIT" \
        | grep -q 'Server: squid'
}

download-cert
if [ $? -ne 0 ]; then
    echo "No proxy server detected"
    exit 0
fi

grep -q '\-----BEGIN CERTIFICATE-----' docker-proxy.pem
if [ $? -ne 0 ]; then
    echo "Proxy detected"
    exit 0
fi

echo "SSL-caching proxy server detected. Installing certificate."

# Install CA cert into OS key store
cp docker-proxy.pem /usr/local/share/ca-certificates/docker-proxy.crt
update-ca-certificates
