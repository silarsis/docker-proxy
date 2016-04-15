# docker-proxy

Transparent caching proxy server for docker containers, run in a docker
container. It can speed up the dependency-fetching part of your application
build process.

## Instructions for Use

Build first with:

```
sudo docker build -t docker-proxy .
```

Then run with:

```
./run.sh
```

For Max(OSX):
```
docker-machine scp ./run.sh default:/home/docker/run.sh
docker-machine ssh default
sh ./run.sh
```

The "run.sh" script will run the container and setup the appropriate iptables
and ip routing rules.

NOTE: This project is _not_ designed to be run with a simple `docker run` - it
requires the `run.sh` script to be run on the docker host, so it can adjust the
routing rules. You will need to check this code out
and run the `run.sh` script on the host (for OS X, that's on your boot2docker or
similar host).

## Overview

The `run.sh` script will fire up a docker container running squid, with
appropriate firewall rules in place for transparent proxying. It will also
configure port-based routing on the main host such that any traffic from a
docker container to port 80 routes via the transparent proxy container. It
requires `sudo` access to perform the firewall changes, and it will prompt you
for your password as appropriate.

The `run.sh` script is designed to run in the foreground, because when the
container terminates it needs to remove the rules that were redirecting the
traffic.

If you want to see squid in operation, you can (in another terminal) attach
to the squid container - it is tailing the access log, so will show a record
of requests made.

## HTTPS Support

The proxy server supports HTTPS caching via Squid's [SSL Bump] feature. To
enable it, start with:

```
./run.sh ssl
```

The server will decrypt traffic from the server and encrypt it again using its
own root certificate. HTTPS connections from your other Docker containers will
fail until you install the root certificate. To install it:

 1. Install the `ca-certificates` package (Debian/Ubuntu images)
 2. Run [`detect-proxy.sh`]

Those steps can be performed in a running container (for testing), or you can
add them to your `Dockerfile`. `detect-proxy.sh` can be run after you install
your OS packages with apt, because apt shouldn't need HTTPS. However, adding
PPAs with `add-apt-repository` will fail until the certificate is installed. See
[`test/Dockerfile`] for an example.

To test HTTPS support, do this in another console after starting the proxy:

```
cd test
sudo docker build -t test-proxy .
sudo docker run --rm test-proxy
# Should print "All tests passed"
```

[SSL Bump]: http://wiki.squid-cache.org/Features/SslBump
[`detect-proxy.sh`]: test/detect-proxy.sh
[`test/Dockerfile`]: test/Dockerfile

## Notes

This proxy configuration is intended to be used solely to speed
up development of Docker applications. **Do not** attempt to use this to
eavesdrop on other people's connections.

There exists a real possibility this script will break your iptables or ip
rules in some unexpected way. Be aware that if things go wrong, the potential
exists for all containers to lose the ability to download anything.
