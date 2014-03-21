FROM silarsis/base
MAINTAINER Kevin Littlejohn <kevin@littlejohn.id.au>
RUN apt-get -yq update && apt-get -yq upgrade

RUN apt-get -yq install squid iptables
ADD squid.conf /etc/squid3/squid.conf
ADD start_squid.sh /usr/local/bin/start_squid.sh

EXPOSE 3128

CMD ["/usr/local/bin/start_squid.sh"]
