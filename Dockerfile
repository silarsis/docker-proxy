FROM silarsis/base
MAINTAINER Kevin Littlejohn <kevin@littlejohn.id.au>
RUN apt-get -yq update && apt-get -yq upgrade

RUN apt-get -yq install squid iptables
ADD squid.conf /etc/squid3/squid.conf
ADD runsquid.sh /usr/local/bin/runsquid.sh

EXPOSE 3128

CMD ["/usr/local/bin/runsquid.sh"]
