#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

name "redis"
version "2.4.7"

source :url => "http://redis.googlecode.com/files/redis-2.4.7.tar.gz",
       :md5 => "6afffb6120724183e40f1cac324ac71c"

relative_path "redis-2.4.7"

make_args = ["PREFIX=#{install_dir}/embedded",
             "CFLAGS='-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include'",
             "LD_RUN_PATH=#{install_dir}/embedded/lib"].join(" ")

config = <<-CONFIG
daemonize yes
pidfile /var/run/redis/redis-flapjack.pid
port 6380
bind 127.0.0.1
timeout 300
loglevel notice
logfile /var/log/redis/redis-flapjack.log
databases 16
save 900 1
save 300 10
save 60 10000
rdbcompression yes
dbfilename dump.rdb
dir /var/lib/redis
slave-serve-stale-data yes
appendonly no
appendfsync everysec
no-appendfsync-on-rewrite no
vm-enabled no
vm-swap-file /var/lib/redis/redis.swap
CONFIG

init = <<-INIT
#! /bin/sh
### BEGIN INIT INFO
# Provides:   redis-flapjack
# Required-Start: $syslog $remote_fs
# Required-Stop:  $syslog $remote_fs
# Should-Start:   $local_fs
# Should-Stop:    $local_fs
# Default-Start:  2 3 4 5
# Default-Stop:   0 1 6
# Short-Description:  redis-flapjack - Persistent key-value db for Flapjack
# Description:    redis-flapjack - Persistent key-value db for Flapjack
### END INIT INFO


PATH=#{install_dir}/embedded/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=#{install_dir}/embedded/bin/redis-server
DAEMON_ARGS=#{install_dir}/embedded/etc/redis-flapjack.conf
NAME=redis-server
DESC=redis-server

RUNDIR=/var/run/redis
PIDFILE=$RUNDIR/redis-flapjack.pid

test -x $DAEMON || exit 0

set -e

case "$1" in
  start)
  echo -n "Starting $DESC: "
  mkdir -p $RUNDIR
  touch $PIDFILE
  chown redis:redis $RUNDIR $PIDFILE
  chmod 755 $RUNDIR
  if start-stop-daemon --start --quiet --umask 007 --pidfile $PIDFILE --chuid redis:redis --exec $DAEMON -- $DAEMON_ARGS
  then
    echo "$NAME."
  else
    echo "failed"
  fi
  ;;
  stop)
  echo -n "Stopping $DESC: "
  if start-stop-daemon --stop --retry forever/QUIT/1 --quiet --oknodo --pidfile $PIDFILE --exec $DAEMON
  then
    echo "$NAME."
  else
    echo "failed"
  fi
  rm -f $PIDFILE
  ;;

  restart|force-reload)
  ${0} stop
  ${0} start
  ;;

  status)
  echo -n "$DESC is "
  if start-stop-daemon --stop --quiet --signal 0 --name ${NAME} --pidfile ${PIDFILE}
  then
    echo "running"
  else
    echo "not running"
    exit 1
  fi
  ;;

  *)
  echo "Usage: /etc/init.d/$NAME {start|stop|restart|force-reload}" >&2
  exit 1
  ;;
esac

exit 0
INIT

build do
  command ["make -j #{max_build_jobs}", make_args].join(" ")
  command ["make install", make_args].join(" ")

  etc_path = "#{install_dir}/embedded/etc"
  command "mkdir #{etc_path}/redis"
  command "mkdir #{etc_path}/init.d"

  config_path = "#{etc_path}/redis/redis-flapjack.conf"
  File.open(config_path, 'w') { |f| f << config }
  init_path   = "#{etc_path}/init.d/redis-flapjack"
  File.open(init_path, 'w') { |f| f << init }
end
