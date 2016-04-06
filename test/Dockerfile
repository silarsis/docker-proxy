FROM ubuntu:14.04

MAINTAINER Alex Fraser <alex@vpac-innovations.com.au>

# Run a caching proxy on the host and bind a port to APT_PROXY_PORT to cache
# apt requests. Build with `docker build --build-arg APT_PROXY_PORT=[X] [...]`.
WORKDIR /root
COPY detect-proxy.sh /root/
RUN export DEBIAN_FRONTEND=noninteractive TERM=linux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
    && ./detect-proxy.sh start

CMD curl -O https://httpbin.org/get
