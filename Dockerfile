FROM ubuntu:14.04

MAINTAINER Kevin Littlejohn <kevin@littlejohn.id.au>, \
    Alex Fraser <alex@vpac-innovations.com.au>

# Install base dependencies.
WORKDIR /root
RUN sed -i 's/^# deb-src/deb-src/' /etc/apt/sources.list
RUN export DEBIAN_FRONTEND=noninteractive TERM=linux \
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

# Customise and build Squid.
# It's silly, but run dpkg-buildpackage again if it fails the first time. This
# is needed because sometimes the `configure` script is busy when building in
# Docker after autoconf sets its mode +x.
COPY squid3.patch mime.conf /root/
RUN cd squid3-3.* \
    && patch -p1 < /root/squid3.patch \
    && export NUM_PROCS=`grep -c ^processor /proc/cpuinfo` \
    && (dpkg-buildpackage -b -j${NUM_PROCS} \
        || dpkg-buildpackage -b -j${NUM_PROCS}) \
    && DEBIAN_FRONTEND=noninteractive TERM=linux dpkg -i \
        ../squid3-common_3.*_all.deb \
        ../squid3_3.*.deb \
    && mkdir -p /etc/squid3/ssl_cert \
    && cat /root/mime.conf >> /usr/share/squid3/mime.conf

COPY squid.conf /etc/squid3/squid.conf
COPY start_squid.sh /usr/local/bin/start_squid.sh

VOLUME /var/spool/squid3 /etc/squid3/ssl_cert
EXPOSE 3128 3129 3130

CMD ["/usr/local/bin/start_squid.sh"]
