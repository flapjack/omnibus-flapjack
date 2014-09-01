# flapjack Omnibus project

This project creates full-stack platform-specific packages for
`flapjack` and maintains appropriate package repositories at
[packages.flapjack.io](http://packages.flapjack.io/)

## Installation

We'll assume you have Ruby 1.9+ and Bundler installed. First ensure all
required gems are installed and ready to use:

```shell
$ bundle install --binstubs
```
Also make sure you have fpm and the required tools to build packages (such as rpm-build on rpm based platform)
installed


## Usage

### Build

After setting the FLAPJACK_BUILD_TAG
You create a platform-specific package using the `build project` command:

```shell
$ export FLAPJACK_BUILD_TAG="0.8.4"
$ bin/omnibus build project flapjack
```

The platform/architecture type of the package created will match the platform
where the `build project` command is invoked. So running this command on say a
MacBook Pro will generate a Mac OS X specific package. After the build
completes packages will be available in `pkg/`.

### Clean

You can clean up all temporary files generated during the build process with
the `clean` command:

```shell
$ bin/omnibus clean
```

Adding the `--purge` purge option removes __ALL__ files generated during the
build including the project install directory (`/opt/flapjack`) and
the package cache directory (`/var/cache/omnibus/pkg`):

```shell
$ bin/omnibus clean --purge
```

### Help

Full help for the Omnibus command line interface can be accessed with the
`help` command:

```shell
$ bin/omnibus help
```

## Vagrant-based Virtualized Build Lab

This Omnibus project ships will a project-specific
[Berksfile](http://berkshelf.com/) and [Vagrantfile](http://www.vagrantup.com/)
that will allow you to build your projects on various platforms, including:

* CentOS 5 64-bit
* CentOS 6 64-bit
* Ubuntu 10.04 64-bit
* Ubuntu 11.04 64-bit
* Ubuntu 12.04 64-bit

Please note this build-lab is only meant to get you up and running quickly;
there's nothing inherent in Omnibus that restricts you to just building CentOS
or Ubuntu packages. See the Vagrantfile to add new platforms to your build lab.

The only requirements for standing up this virtualized build lab are:

* VirtualBox, VMWare Fusion, or AWS EC2
* Vagrant 1.4.3+ - native packages exist for most platforms and can be downloaded
from the [Vagrant downloads page](http://downloads.vagrantup.com/).

The [vagrant-berkshelf](https://github.com/RiotGames/vagrant-berkshelf) and
[vagrant-omnibus](https://github.com/schisamo/vagrant-omnibus) Vagrant plugins
are also required and can be installed easily with the following commands:

```shell
vagrant plugin install vagrant-berkshelf
vagrant plugin install vagrant-omnibus
```

Once the pre-requisites are installed you can build your package across all
platforms with the following command:

```shell
export FLAPJACK_BUILD_TAG="0.8.4"
vagrant up
```
(Change the tag to build in the `FLAPJACK_BUILD_TAG` environment variable.)

If you would like to build a package for a single platform the command looks like this:

```shell
export FLAPJACK_BUILD_TAG="0.8.4"
vagrant up PLATFORM
```

The complete list of valid platform names can be viewed with the
`vagrant status` command.

We've also defined a custom instance that uses the official Vagrant Ubuntu
Precise (12.04) box:

``` shell
export FLAPJACK_BUILD_TAG="0.8.4"
vagrant up ubuntu-precise64
```

To rebuild the omnibus package without destroying the instance, you can do this:

``` shell
vagrant provision ubuntu-precise64
```

## Automatic upload to S3

Currently, built packages will be uploaded to `s3://flapjack-packages/new/` though this URL can be overridden with the `FLAPJACK_TARGET_S3_URL` environment variable. The AWS key id and secret key also need to be set in environment variables, see `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and other environment variables in the section below.

You can disable this behaviour by setting the `SKIP_S3_STORE` environment variable.

## Updating the debian package repo (ubuntu precise only at present)

Set the following environment variable before running the `vagrant up` command below.

```
export FLAPJACK_UPDATE_REPO='yes'
```

## Building packages on AWS EC2

The default region set up in the Vagrantfile is 'ap-southeast-2' (Sydney, Australia) with ami-978916ad, Canonical's Ubuntu Precise 12.04 LTS amd64 ebs Amazon Machine Image. The example below mentions ami-0568456c which is the equivalent ami for use in us-east-1 (Virginia). Other Linux OS's should also work but have not yet been tested on ec2.

**AWS Setup:**

- There must be a keypair named 'vagrant-flapjack' under your AWS account, for the region you are going to use.
- Your security policy must also allow inbound SSH (port 22), eg by adding a rule to your default security group for the region you're going to use.

**Shell Environment Setup:**

``` bash
# Required:
export AWS_ACCESS_KEY_ID=''
export AWS_SECRET_ACCESS_KEY=''
export AWS_SSH_PRIVATE_KEY_PATH="${HOME}/.ssh/vagrant-flapjack.pem"
export VAGRANT_REMOTE_USER='ubuntu'

# Optional - select an alternative region+ami (default: ap-southeast-2, precise64):
export AWS_REGION="us-east-1"  # DANGER: see the Warning below
export AWS_AMI="ami-0568456c"

# Optional - select an alternative instance type (default: c3.large)
export AWS_INSTANCE_TYPE="m3.medium"

# Optional - have packages.flapjack.io deb repo updated with the freshly built package
export FLAPJACK_UPDATE_REPO="yes"
```

**WARNING**

If you have an aws instance running, and so much as run `vagrant status aws-ubuntu-precise64` without setting AWS_REGION (and probably other environment variables) correctly, then Vagrant will go ahead and remove all knowledge of your running instance, so you won't be able to control it (eg to shut it down) from Vagrant anymore. For this reason it's recommended to stick with the default region that's configured in Vagrantfile.

**Vagrant AWS Plugin:**
```bash
$ vagrant plugin install vagrant-aws
```

**Running Vagrant:**
```
export FLAPJACK_BUILD_TAG="0.8.4"
vagrant up aws-ubuntu-precise64 --provider aws
# manually do something with the generated package (to be automated)
vagrant destroy aws-ubuntu-precise64
```


# Bootstrapping a package build environment on ec2

Notes on attempting to get the vagrant build environment running on an ec2 instance with the vagrant-aws plugin/provider.

- create an ec2 instance from ubuntu-trusty-14.04-amd64-server-20140607.1 (ami-864d84ee)
- install packages:

```
sudo apt-get update
sudo apt-get install -y \
    git \
    curl \
    build-essential \
    ruby1.9.1-full \
    libssl-dev \
    libreadline-dev \
    libxslt1-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libexpat1-dev \
    libicu-dev
```

- install vagrant 1.4.3

```
wget https://dl.bintray.com/mitchellh/vagrant/vagrant_1.4.3_x86_64.deb
sudo dpkg -i vagrant_1.4.3_x86_64.deb
```

- install vagrant plugins:

```
vagrant plugin install vagrant-aws
vagrant plugin install --plugin-version 1.3.7 vagrant-berkshelf
vagrant plugin install --plugin-version 1.3.1 vagrant-omnibus
```

more to come!

