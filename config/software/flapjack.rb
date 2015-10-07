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
# dependency "nokogiri"

relative_path "flapjack"

etc_path = "#{install_dir}/embedded/etc"
omnibus_flapjack_path = Dir.pwd

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
    "if [ ! -d flapjackfeeder ] ; then git clone https://github.com/flapjack/flapjackfeeder.git flapjackfeeder ; fi && " +
    "cd flapjackfeeder && " +
    "make && " +
    "cd .. && " +
    "cp flapjackfeeder/flapjackfeeder3-*.o flapjackfeeder3.o && " +
    "cp flapjackfeeder/flapjackfeeder4-*.o flapjackfeeder4.o && " +
    "rm -r flapjackfeeder"

    command "cp #{omnibus_flapjack_path}/dist/etc/init.d/flapjack* #{etc_path}/init.d/"
    command "cp #{omnibus_flapjack_path}/dist/etc/init.d/flapper* #{etc_path}/init.d/"
end
