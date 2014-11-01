
name "redis"
default_version "2.8.3"

source :url => "http://download.redis.io/releases/redis-2.8.3.tar.gz",
       :md5 => "6327e6786130b556b048beef0edbdfa7"

relative_path "redis-2.8.3"

etc_path = "#{install_dir}/embedded/etc"

make_args = ["PREFIX=#{install_dir}/embedded",
             "CFLAGS='-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include'",
             "LD_RUN_PATH=#{install_dir}/embedded/lib"].join(" ")

config = <<-CONFIG
daemonize yes
pidfile /var/run/flapjack/redis-flapjack.pid
port 6380
bind 0.0.0.0
timeout 300
loglevel notice
logfile /var/log/flapjack/redis-flapjack.log
databases 16
save 900 1
save 300 10
save 60 10000
rdbcompression yes
dbfilename dump.rdb
dir /var/lib/flapjack/redis-flapjack
slave-serve-stale-data yes
appendonly no
appendfsync everysec
no-appendfsync-on-rewrite no
CONFIG

deb_init = <<-INIT
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
DAEMON_ARGS=#{install_dir}/embedded/etc/redis/redis-flapjack.conf
NAME=redis-server
DESC=redis-server

RUNDIR=/var/run/flapjack
PIDFILE=$RUNDIR/redis-flapjack.pid

test -x $DAEMON || exit 0

set -e

case "$1" in
  start)
  echo -n "Starting $DESC: "
  mkdir -p $RUNDIR
  touch $PIDFILE
  chown flapjack:flapjack $RUNDIR $PIDFILE
  chmod 755 $RUNDIR
  if start-stop-daemon --start --quiet --umask 007 --pidfile $PIDFILE --chuid flapjack:flapjack --exec $DAEMON -- $DAEMON_ARGS
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

rpm_init = <<-INIT
#!/bin/bash
#
# redis-flapjack	Persistent key-value db for Flapjack
#
# chkconfig: 2345 80 30
# description: Persistent key-value db for Flapjack
# processname: redis-flapjack
# pidfile: /var/run/flapjack/redis-flapjack.pid
# config: /opt/flapjack/embedded/etc/redis/redis-flapjack.conf

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

# Source function library.
. /etc/rc.d/init.d/functions

RETVAL=0
PATH=/opt/flapjack/embedded/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/opt/flapjack/embedded/bin/redis-server
DAEMON_ARGS=/opt/flapjack/embedded/etc/redis/redis-flapjack.conf
NAME=redis-server
DESC=redis-server

RUNDIR=/var/run/flapjack
PIDFILE=$RUNDIR/redis-flapjack.pid

start() {
    [ -x $DAEMON ] || exit 5
    [ -f $DAEMON_ARGS ] || exit 6
    echo -n "Starting $NAME: "
    daemon --user flapjack --pidfile $PIDFILE $DAEMON $DAEMON_ARGS &
    retval=$?
    echo
    [ $retval -eq 0 ] && touch $PIDFILE
}

stop() {
    echo -n $"Stopping $NAME: "
    if [ -n "`pgrep $NAME`" ] ; then
        killproc $NAME
    RETVAL=3
    else
        failure $"Stopping $DAEMON"
    fi
    retval=$?
    echo
    [ $retval -eq 0 ] && rm -f $PIDFILE
}

restart() {
    stop
    start
}

reload() {
    restart
}

force_reload() {
    restart
}

rh_status() {
    # run checks to determine if the service is running or use generic status
    status $DAEMON
}

rh_status_q() {
    rh_status >/dev/null 2>&1
}


case "$1" in
    start)
        rh_status_q && exit 0
        $1
        ;;
    stop)
        rh_status_q || exit 0
        $1
        ;;
    restart)
        $1
        ;;
    reload)
        rh_status_q || exit 7
        $1
        ;;
    force-reload)
        force_reload
        ;;
    status)
        rh_status
        ;;
    condrestart|try-restart)
        rh_status_q || exit 0
        restart
        ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload}"
        exit 2
esac
exit $?
INIT

build do
  command ["make -j #{max_build_jobs}", make_args].join(" ")
  command ["make install", make_args].join(" ")

  command "mkdir -p '#{etc_path}/redis'"
  command "mkdir -p '#{etc_path}/init.d'"

  command "cat >#{etc_path}/redis/redis-flapjack.conf <<EOCONFIG\n#{config.gsub(/\$/, '\\$')}EOCONFIG"
  command "cat >#{etc_path}/init.d/redis-flapjack-rpm <<EOINIT\n#{rpm_init.gsub(/\$/, '\\$')}EOINIT"
  command "cat >#{etc_path}/init.d/redis-flapjack-deb <<EOINIT\n#{deb_init.gsub(/\$/, '\\$')}EOINIT"

  command "touch #{etc_path}/redis/redis-flapjack.conf"
  command "touch #{etc_path}/init.d/redis-flapjack"
end
