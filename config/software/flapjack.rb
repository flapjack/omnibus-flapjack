name "flapjack"

build_ref = ENV['FLAPJACK_BUILD_REF']
package_version = ENV['FLAPJACK_EXPERIMENTAL_PACKAGE_VERSION']

raise "FLAPJACK_BUILD_REF must be set" unless build_ref
raise "FLAPJACK_EXPERIMENTAL_PACKAGE_VERSION must be set" unless package_version

default_version package_version

compile_go_components = package_version =~ /^0\.9\./ ? false : true

dependency "ruby"
dependency "rubygems"
dependency "bundler"
dependency "nokogiri"

relative_path "flapjack"

build do
  command "if [ ! -d flapjack_source ] ; then git clone https://github.com/flapjack/flapjack.git flapjack_source ; fi"
  command "cd flapjack_source && " +
          "git checkout master && " +
          "git pull && " +
          "git checkout #{build_ref} && " +
          "/opt/flapjack/embedded/bin/gem build flapjack.gemspec"
  gem [ "install /var/cache/omnibus/src/flapjack/flapjack_source/flapjack*gem",
        "--bindir #{install_dir}/bin",
        "--no-rdoc --no-ri" ].join(" ")

  command "export gem_home=/" +
          "`/opt/flapjack/embedded/bin/gem list --all --details flapjack | " +
          "  grep 'Installed at' | sed 's/^.* \\///'` ; " +
          "echo \"gem_home: ${gem_home}\" ; " +
          "export installed_gem=`ls -dtr ${gem_home}/gems/flapjack* | tail -1` ; " +
          "cd ${installed_gem}"
  if compile_go_components
    command "export gem_home=/" +
      "`/opt/flapjack/embedded/bin/gem list --all --details flapjack | " +
      "  grep 'Installed at' | sed 's/^.* \\///'` ; " +
      "echo \"gem_home: ${gem_home}\" ; " +
      "export installed_gem=`ls -dtr ${gem_home}/gems/flapjack* | tail -1` ; " +
      "cd ${installed_gem} && " +
      "./build.sh"
  end

  # Build flapjackfeeder, as per https://github.com/flapjack/flapjackfeeder
  command "export gem_home=/" +
    "`/opt/flapjack/embedded/bin/gem list --all --details flapjack | " +
    "  grep 'Installed at' | sed 's/^.* \\///'` ; " +
    "echo \"gem_home: ${gem_home}\" ; " +
    "export installed_gem=`ls -dtr ${gem_home}/gems/flapjack* | tail -1` ; " +
    "cd ${installed_gem} && " +
    "if [ ! -d hiredis ] ; then git clone https://github.com/redis/hiredis.git hiredis ; fi" +
    "cd hiredis && " +
    "make hiredis-example && " +
    "cd .. " +
    "if [ ! -d flapjackfeeder ] ; then git clone https://github.com/flapjack/flapjackfeeder.git flapjackfeeder ; fi" +
    "cd flapjackfeeder && " +
    "(cd src ; gcc -fPIC -g -O2 -DHAVE_CONFIG_H -DNSCORE -o flapjackfeeder.o flapjackfeeder.c -shared -fPIC ../../hiredis/libhiredis.a ;strip flapjackfeeder.o) && " +
    "cd .. " +
    "cp flapjackfeeder/src/flapjackfeeder.o ." +
    "rm -r flapjackfeeder hiredis"
end
