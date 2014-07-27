name "flapjack"

build_ref = ENV['FLAPJACK_BUILD_REF']
package_version = ENV['FLAPJACK_PACKAGE_VERSION']

raise "FLAPJACK_BUILD_REF must be set" unless build_ref
raise "FLAPJACK_PACKAGE_VERSION must be set" unless package_version

default_version package_version

etc_path = "#{install_dir}/embedded/etc"

dependency "ruby"
dependency "rubygems"
dependency "bundler"
dependency "nokogiri"

#source :git => "https://github.com/flapjack/flapjack"

relative_path "flapjack"

flapjack = <<FLAPJACK
#!/bin/bash

### BEGIN INIT INFO
# Provides:       flapjack
# Required-Start: $syslog $remote_fs redis-flapjack
# Required-Stop:  $syslog $remote_fs redis-flapjack
# Should-Start:   $local_fs
# Should-Stop:    $local_fs
# Default-Start:  2 3 4 5
# Default-Stop:   0 1 6
# Short-Description:  flapjack - scalable monitoring notification system
# Description:    flapjack - scalable monitoring notification system
### END INIT INFO

# Copyright (c) 2009-2013 Lindsay Holmwood <lindsay@holmwood.id.au>
#
# Boots flapjack (coordinator, processor, notifier, gateways...)

PATH=/opt/flapjack/bin:$PATH

if [ ! $(which flapjack) ]; then
  echo "Error: flapjack isn't in PATH."
  echo "Refusing to do anything!"
  exit 1
fi

# Evaluate command
flapjack server $@

RETVAL=$?
exit $RETVAL
FLAPJACK

flapnagios = <<FLAPNAGIOS
#!/bin/bash
#
# Copyright (c) 2009-2013 Lindsay Holmwood <lindsay@holmwood.id.au>
#
# flapjack-nagios-receiver
# reads from a nagios perfdata named-pipe and submits each event to the events queue in redis
#

PATH=/opt/flapjack/bin:$PATH

if [ ! $(which flapjack) ]; then
  echo "Error: flapjack isn't in PATH."
  echo "Refusing to do anything!"
  exit 1
fi

# Evaluate command
flapjack receiver nagios $1 --daemonize

RETVAL=$?
exit $RETVAL
FLAPNAGIOS

flapper = <<FLAPPER
#!/bin/bash
#
# flapper
#

PATH=/opt/flapjack/bin:$PATH

if [ ! $(which flapjack) ]; then
  echo "Error: flapjack isn't in PATH."
  echo "Refusing to do anything!"
  exit 1
fi

# Evaluate command
flapjack flapper $1

RETVAL=$?
exit $RETVAL
FLAPPER

build do
  # Install all dependencies
  #command "rm Gemfile.lock"
  #command "PATH=#{install_dir}/embedded/bin:${PATH} ; export PATH"

  #bundle "install --path=#{install_dir}/embedded/service/gem"
  #command "PATH=#{install_dir}/embedded/bin:$PATH" +
  #        " #{install_dir}/embedded/bin/bundle install" +
  #        " --path=#{install_dir}/embedded/service/gem"

  # Build + install the gem
  #bundle "exec rake build"
  #command "PATH=#{install_dir}/embedded/bin:$PATH" +
  #        " #{install_dir}/embedded/bin/bundle install" +
  #        " --path=#{install_dir}/embedded/service/gem"

  command "git clone https://github.com/flapjack/flapjack.git flapjack_source"
  command "cd /var/cache/omnibus/src/flapjack/flapjack_source && " +
          "git checkout #{build_ref} && "
          "/opt/flapjack/embedded/bin/gem build flapjack.gemspec"
          #"/opt/flapjack/embedded/bin/bundle install && " +
          #"/opt/flapjack/embedded/bin/bundle exec " +
          #"/opt/flapjack/embedded/bin/rake build"
  gem [ "install /var/cache/omnibus/src/flapjack/flapjack_source/flapjack*gem",
        "--bindir #{install_dir}/bin",
        "--no-rdoc --no-ri" ].join(" ")

  #gem [ "install flapjack --version #{ENV['FLAPJACK_BUILD_TAG']}",
  #      "--bindir #{install_dir}/bin",
  #      "--no-rdoc --no-ri" ].join(" ")

  #command "PATH=#{install_dir}/embedded/bin:$PATH" +
  #        " #{install_dir}/embedded/bin/gem install flapjack --version #{ENV['FLAPJACK_BUILD_TAG']}" +
  #        " --bindir #{install_dir}/bin" +
  #        " --no-rdoc --no-ri"

  command "mkdir -p '#{etc_path}/init.d'"

  command "cat >#{etc_path}/init.d/flapjack <<EOFLAPJACK\n#{flapjack.gsub(/\$/, '\\$')}EOFLAPJACK"
  command "cat >#{etc_path}/init.d/flapjack-nagios-receiver <<EOFLAPNAGIOS\n#{flapnagios.gsub(/\$/, '\\$')}EOFLAPNAGIOS"
  command "cat >#{etc_path}/init.d/flapper <<EOFLAPPER\n#{flapper.gsub(/\$/, '\\$')}EOFLAPPER"

  command "touch #{etc_path}/init.d/flapjack"
  command "touch #{etc_path}/init.d/flapjack-nagios-receiver"
  command "touch #{etc_path}/init.d/flapper"
end

