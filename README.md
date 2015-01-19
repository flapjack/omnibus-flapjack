# Flapjack Omnibus project

This project creates full-stack platform-specific packages for
[Flapjack](http://flapjack.io) using [omnibus](https://github.com/opscode/omnibus) and maintains appropriate package repositories at [packages.flapjack.io](http://packages.flapjack.io/)

We highly recommend you build this with the included Rakefile, which uses Docker.

You'll need a docker server and a local docker command that can talk to it.
An easy way to get a docker server going is using [boot2docker](http://boot2docker.io/).
A more complicated way is to use an EC2 instance, which is what we use for the official packages.
There's a [packer config](packer-ebs.json) for building the AMIs we use.
See the Flapjack docs on [package building](http://flapjack.io/docs/1.0/development/Package-Building/) and [getting going with boot2docker](http://flapjack.io/docs/1.0/development/Omnibus-In-Your-Docker/).

### AWS CLI Configuration

If you want the build rake task to publish to packages.flapjack.io then you'll need to have set up a valid configuration for aws cli. You can do this as follows:

```
./configure_awscli \
  --aws-access-key-id xxx \
  --aws-secret-access-key xxx \
  --default-region us-east-1
```

### Build

Run the `build` rake task. It drives `docker` and `omnibus` to build packages.

The following environment variables affect what `build` does:

- `BUILD_REF`                 - the branch, tag, or commit (on master) to build (Required). If a tag, it'll start with a v if it's a release tag, eg `v1.0.0rc5`
- `DISTRO`                    - only "ubuntu" is currently supported (Optional, Default: "ubuntu")
- `DISTRO_RELEASE`            - the release name, eg "precise" (Optional, Default: "trusy")
- `DRY_RUN`                   - if set, just shows what would be gone (Optional, Default: nil)
- `OFFICIAL_FLAPJACK_PACKAGE` - if true, signs built packages, assuming that the Flapjack Signing Key is on the system


Eg:

```
export BUILD_REF="1.1.0"
export DISTRO="ubuntu"
export DISTRO_RELEASE="precise"
export OFFICIAL_FLAPJACK_PACKAGE="true"

bundle exec rake build
```

### Publish

Run the `publish` rake task to publish a previously built package. The package is added to the *experimental* component of your apt package repo.

The following environment variable is required:

- `PACKAGE_FILE` - the filename of the package file you've just built and want to publish.  This is assumed to be in omnibus-flapjack/pkg (which is where the Rakefile build puts it)

Eg:

```bash
export PACKAGE_FILE=flapjack_1.1.0~+20141003112645-master-trusty-1_amd64.deb
bundle exec rake build
```

### Testing Packages

The test task starts up a docker instance with a pristine copy of the distribution, installs the package given, and runs Serverspec against it.

The following environment variable is required:

- `PACKAGE_FILE` - the filename of the package file you've just built and want to publish.  This is assumed to be in omnibus-flapjack/pkg (which is where the Rakefile build puts it)


### Build and Test

The rake task `build_and_test` just calls the `build` and `test` rake tasks sequentially. You don't need to set the `PACKAGE_FILE` environment variable however, as the package meta data is already determined.


### Build and Publish

The rake task `build_and_publish` just calls the `build`, `test` and `publish` rake tasks sequentially. You don't need to set the `PACKAGE_FILE` environment variable however, as the package meta data is already determined.

The environment variables are as per the `build` rake task.

Eg:

```
export BUILD_REF="1.1.0"
export DISTRO="ubuntu"
export DISTRO_RELEASE="precise"
bundle exec rake build_and_publish
```


### Promote from Experimental to Main

When testing of the package candidiate is completed, use the `promote` task to repackage the deb for the **main** component in the case of debs, or copy the package to `flapjack` from `flapjack-experimental` in the case of rpms.

You'll need the name of the candidate package, which will be in the output of `build`, or look in S3 to find it. Eg:

```bash
export PACKAGE_FILE=flapjack_1.1.0~+20141003112645-master-trusty-1_amd64.deb
bundle exec rake promote
```

### Tests

Tests are fairly minimal right now, would you like to expand them? Check out the spec directory! Run with:

```
bundle install
bundle exec rspec
```
