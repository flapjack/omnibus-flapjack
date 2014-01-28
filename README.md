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

## Usage

### Build

You create a platform-specific package using the `build project` command:

```shell
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
$ vagrant plugin install vagrant-berkshelf
$ vagrant plugin install vagrant-omnibus
```

Once the pre-requisites are installed you can build your package across all
platforms with the following command:

```shell
$ vagrant up
```

If you would like to build a package for a single platform the command looks like this:

```shell
$ vagrant up PLATFORM
```

The complete list of valid platform names can be viewed with the
`vagrant status` command.

We've also defined a custom instance that uses the official Vagrant Ubuntu
Precise (12.04) box:

``` shell
$ vagrant up ubuntu-precise64
```

To rebuild the omnibus package without destroying the instance, you can do this:

``` shell
$ vagrant provision ubuntu-precise64
```

## Automatic upload to S3

Currently, built packages will be uploaded to `s3://flapjack-packages/new/` though this URL can be overridden with the `FLAPJACK_TARGET_S3_URL` environment variable. The AWS key id and secret key also need to be set in environment variables, see `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and other environment variables in the section below.

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

# Optionsl - select an alternative instance type (default: c3.large)
export AWS_INSTANCE_TYPE="m3.medium"
```

**WARNING**

If you have an aws instance running, and so much as run `vagrant status aws-ubuntu-precise64` without setting AWS_REGION (and probably other environment variables) correctly, then Vagrant will go ahead and remove all knowledge of your running instance, so you won't be able to control it (eg to shut it down) from Vagrant anymore. For this reason it's recommended to stick with the default region that's configured in Vagrantfile.

**Vagrant AWS Plugin:**
```bash
vagrant plugin install vagrant-aws
```

**Running Vagrant:**
```
vagrant up aws-ubuntu-precise64 --provider aws
# manually do something with the generated package (to be automated)
vagrant destroy aws-ubuntu-precise64
```

## Updating the debian package repo (ubuntu precise only at present)

For now this is manually done within the running vagrant vm after omnibus has successfully built the package.

SSH in to ubuntu-precise64 vm:

``` bash
vagrant ssh ubuntu-precise64
```

Install reprepro, pip and awscli etc (if you haven't already):

``` bash
sudo apt-get install reprepro python-pip groff
sudo pip install awscli
```

Configure awscli with your access credentials (if you haven't already):

``` bash
aws configure --profile default
```
Note, this saves your AWS keys into your home directory, so think thrice about doing this on a shared machine.

Use 'us-east-1' as the default region.

Clone the packages.flapjack.io git repo (if you haven't already):

``` bash
mkdir -p ~/src && cd ~/src && git clone https://github.com/flpjck/packages.flapjack.io.git
```

Pull the latest commits (unless you've just cloned):
``` bash
cd ~/src/packages.flapjack.io && git pull
```

Retrive the current debian repository:

``` bash
~/src/packages.flapjack.io/bin/sync_deb_down
```

Add the new flapjack package to the debian repo

``` bash
reprepro -b ~/src/packages.flapjack.io/deb includedeb precise `ls ~/omnibus-flapjack/pkg/flapjack*deb | tail -1`
```

Check you can see the new flapjack package in the output of `dpkg-scanpackages`, and that the Size, Installed-Size, etc look reasonable:

``` bash
dpkg-scanpackages ~/src/packages.flapjack.io/deb
```

Eg, example output for 0.7.27:

``` text
Package: flapjack
Version: 0.7.27+20131020221016-1.ubuntu.12.04
Architecture: amd64
Maintainer: Lindsay Holmwood <lindsay@holmwood.id.au>
Installed-Size: 420086
Replaces: flapjack
Filename: src/packages.flapjack.io/deb/pool/main/f/flapjack/flapjack_0.7.27+20131020221016-1.ubuntu.12.04_amd64.deb
Size: 138195228
MD5sum: e75058def111248074286933707efe6e
SHA1: 85f2ed6b379c85a42d11f1802f9a0740bf49e2db
SHA256: b99444329044cfc956a48ef39c996519678ecab3060eb1fbaa151a31bb5dd90f
Section: default
Priority: extra
Homepage: http://flapjack.io
Description: The full stack of flapjack
License: unknown
Vendor: vagrant@flapjack-omnibus-build-lab
```

Create directory listing html file for every directory within the deb repo with:

``` bash
cd ~/src/packages.flapjack.io && bin/create_directory_listings deb
```

Sync the debian repo back up to packages.flapjack.io, first with a dryrun:

``` bash
~/src/packages.flapjack.io/bin/sync_deb_up
```

Then add 'apply=true' and run again if you're happy with what's going to be done.

Check that the latest package is available for download at [http://packages.flapjack.io/deb/pool/main/f/flapjack/](http://packages.flapjack.io/deb/pool/main/f/flapjack/)

