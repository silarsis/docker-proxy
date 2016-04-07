FROM ubuntu:14.04

MAINTAINER Alex Fraser <alex@vpac-innovations.com.au>

# Install ca-certificates so we can install the proxy's certificate. curl and
# Java are  only needed for running the test, not for installing the
# certificate.
WORKDIR /root
RUN export DEBIAN_FRONTEND=noninteractive TERM=linux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        default-jdk \
    && rm -rf /var/lib/apt/lists/*

# Install the proxy's CA certificate.
COPY detect-proxy.sh test-proxy.sh HttpTest.java /root/
RUN javac HttpTest.java \
    && ./detect-proxy.sh start

CMD /root/test-proxy.sh
