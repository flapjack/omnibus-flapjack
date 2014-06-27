# Building Flapjack using Omnibus 3 and Docker

**Note:** This is a work in progress. At the time of writing (late June 2014) I have [some problems](https://github.com/flapjack/omnibus-flapjack/issues/21) preventing the build of a correct package. More hacking to come.

## Set up a docker server

The easiest way to do this is to use [boot2docker-cli](https://github.com/boot2docker/boot2docker-cli) to manage a VirtualBox VM running [boot2docker linux](https://github.com/boot2docker/boot2docker), a very lightweight linux distro designed to run docker server and not much else (it uses busybox for your shell if you ssh into it). The boot2docker cli is written in Go and runs on Mac OS, Windows and Linux. 

Here's how I installed it on Mac OS X Mavericks (10.9.3) with homebrew and VirtualBox 4.3.10 already installed:

```
brew update
brew install boot2docker
```

Specify some configuration, in particular so the IP range is within a subnet that your VPN is not going to grab routes to:

**~/.boot2docker/profile**

```
DiskSize = 20000
Memory = 2048
SSHPort = 2022
DockerPort = 2375
HostIP = "172.20.10.3"
DHCPIP = "172.20.10.99"
NetMask = [255, 255, 255, 0]
LowerIP = "172.20.10.103"
UpperIP = "172.20.10.254"
DHCPEnabled = true
```

Create, and start up, your boot2docker docker server:

```
boot2docker init
boot2docker start
```

It'll give you an address to set DOCKER_HOST to so that your docker cli knows how to access your docker server, so you'll then need to run something the following:

```
export DOCKER_HOST=tcp://172.20.10.103:2375
```

Test that everything is working:

```
docker ps
```

You should see:

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
```

This shows that there are no docker containers running.

## I like to build it build it

Pull down the latest flapjack/omnibus-ubuntu image from the docker registry:

```
docker pull flapjack/omnibus-ubuntu
```

It's about 750 MB worth I think. Details here:
- https://registry.hub.docker.com/u/flapjack/omnibus-ubuntu/builds_history/27355/

The image is rebuilt automatically when the following repo changes:
- https://github.com/flapjack/omnibus-ubuntu

Once you've got that down, you can create a container by running the flapjack/omnibus-ubuntu image like so:

```
docker run --rm -i -t -e "FLAPJACK_BUILD_TAG=1.0.0rc1" \
  flapjack/omnibus-ubuntu bash -c \
  "cd omnibus-flapjack ; \
  git pull ; \
  bundle install --binstubs ; \
  bin/omnibus build --log-level=info flapjack ; \
  bash"
```

While still shell'd in to the build container (and before the container is purged) you can scp the created package somewhere to test installing it. It can be found at a path like `/omnibus-flapjack/pkg/flapjack*.deb`

