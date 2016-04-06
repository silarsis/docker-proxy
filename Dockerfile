FROM ubuntu:14.04

MAINTAINER Alex Fraser <alex@vpac-innovations.com.au>

# Run a caching proxy on the host and bind a port to APT_PROXY_PORT to cache
# apt requests. Build with `docker build --build-arg APT_PROXY_PORT=[X] [...]`.
WORKDIR /root
ARG APT_PROXY_PORT=
COPY detect-apt-proxy.sh /root/
RUN export DEBIAN_FRONTEND=noninteractive TERM=linux \
    && ./detect-apt-proxy.sh ${APT_PROXY_PORT} no \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        dpkg-dev \
        iptables \
        libssl-dev \
        patch \
        squid-langpack \
        ssl-cert \
    && apt-get source -y squid3 squid-langpack \
    && apt-get build-dep -y squid3 squid-langpack
#    rm -rf /var/lib/apt/lists/* \
#        /etc/apt/apt.conf.d/30proxy \

# It's silly, but run dpkg-buildpackage again if it fails the first time. This
# is needed because sometimes the `configure` script is busy when building in
# Docker after autoconf sets its mode +x.
COPY squid3.patch /root/
RUN cd squid3-3.?.? \
    && patch -p1 < /root/squid3.patch \
    && export NUM_PROCS=`grep -c ^processor /proc/cpuinfo` \
    && (dpkg-buildpackage -b -j${NUM_PROCS} || dpkg-buildpackage -b -j${NUM_PROCS})
RUN dpkg -i \
        squid3-common_3.?.?-?ubuntu?.?_all.deb \
        squid3_3.?.?-?ubuntu?.?_*.deb \
    && mkdir -p /etc/squid3/ssl_cert

ADD squid.conf /etc/squid3/squid.conf
ADD start_squid.sh /usr/local/bin/start_squid.sh

VOLUME /var/spool/squid3
EXPOSE 3128 3129 3130

CMD ["/usr/local/bin/start_squid.sh"]
