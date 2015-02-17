# Flapjack Omnibus project

We highly recommend you build this with the included Rakefile, which uses Docker.  However, if you wish to build this without docker, you can do so as follows:
=======

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
FLAPJACK_BUILD_REF='v1.3.0rc2' \
FLAPJACK_EXPERIMENTAL_PACKAGE_VERSION='1.3.0~rc2~20150216030004~v1.3.0rc2~trusty' \
DISTRO_RELEASE=trusty \
bundle exec bin/omnibus build flapjack
```

### Clean

You can clean up all temporary files generated during the build process with
the `clean` command:

```shell
$ bin/omnibus clean flapjack
```

Adding the `--purge` purge option removes __ALL__ files generated during the
build including the project install directory (`/opt/flapjack`) and
the package cache directory (`/var/cache/omnibus/pkg`):

```shell
$ bin/omnibus clean flapjack --purge
```

### Help

Full help for the Omnibus command line interface can be accessed with the
`help` command:

```shell
$ bin/omnibus help
```
