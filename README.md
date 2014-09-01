# Flapjack Omnibus project

This project creates full-stack platform-specific packages for
[Flapjack](http://flapjack.io) using [omnibus](https://github.com/opscode/omnibus) and maintains appropriate package repositories at [packages.flapjack.io](http://packages.flapjack.io/)


You have some choice over how you run this:

- locally
- within a docker container

If you run locally, you'll be calling `omnibus build` directly rather than using the `build` script, which means you'll miss out on the ability to update packages.flapjack.io with the resulting package.

## Running omnibus locally

You need to have this project checked out on the target platform as cross compilation is not supported.

We'll assume you have Ruby 1.9+ and Bundler installed. First ensure all
required gems are installed and ready to use:

```shell
$ bundle install --binstubs
```

Also make sure you have fpm and the required tools to build packages (such as rpm-build on rpm based platforms) installed.

The platform/architecture type of the package created will match the platform
where the `build` command is invoked. So running this command on say a
MacBook Pro will generate a Mac OS X specific package. After the build
completes packages will be available in `pkg/`, and with a bit of luck on your package repo as well.

### Build

```shell
FLAPJACK_BUILD_REF="v1.0.0rc3" \
FLAPJACK_PACKAGE_VERSION="1.0.0~rc3~20140727T125000-9b1e831-1" \
bundle exec bin/omnibus build project flapjack
```

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

## Running within a Docker container

You'll need a docker server to talk to. An easy way to do this is [using boot2docker](Docker.md). A complicated way is to use an EC2 instance, but that's what we use for the official packages. There's a [packer config](packer-ebs.json) for building AMIs we use.

### AWS CLI Configuration

If you want the build script to publish to packages.flapjack.io then you'll need to have set up a valid configuration for aws cli. You and do this as follows:

```
./configure_awscli \
  --aws-access-key-id xxx \
  --aws-secret-access-key xxx \
  --default-region us-east-1
```

### Build & Publish

Run the build script! It drives `docker`, `omnibus`, `aptly`, and `aws s3`. It takes the following two arguments:

- **build ref** - the git reference to the version of flapjack you want to build. Can be a tag, branch, or sha. If a tag, it'll start with a v if it's a release tag, eg `v1.0.0rc5`
- **distro release** - eg `precise`, `trusty` etc

```shell
$ ./build $build_ref $distro_release
```

eg

```shell
$ ./build v1.0.0rc6 precise
```

If you have your aws cli configured correctly then `build` will also add the resulting package to the *experimental* component of your apt package repo, with the specified distro release.

If you don't want to upload the package you just built, export the skip_package_upload variable.

```shell
export skip_package_upload=true
```
