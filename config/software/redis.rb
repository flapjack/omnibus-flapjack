
name "redis"
default_version "2.8.17"

source :url => "http://download.redis.io/releases/redis-#{version}.tar.gz",
       :md5 => "69023c3005664602268a5e2dbe23425c"

relative_path "redis-2.8.17"

etc_path = "#{install_dir}/embedded/etc"
omnibus_flapjack_path = Dir.pwd

make_args = ["PREFIX=#{install_dir}/embedded",
             "CFLAGS='-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include'",
             "LD_RUN_PATH=#{install_dir}/embedded/lib"].join(" ")

build do
  command ["make -j #{workers}", make_args].join(" ")
  command ["make install", make_args].join(" ")

  command "mkdir -p '#{etc_path}/redis'"
  command "mkdir -p '#{etc_path}/init.d'"

  command "cp -a #{omnibus_flapjack_path}/dist/etc/redis #{etc_path}"
  command "cp #{omnibus_flapjack_path}/dist/etc/init.d/redis* #{etc_path}/init.d/"
end
