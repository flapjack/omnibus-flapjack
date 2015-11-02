name          "flapjack-dependencies"
friendly_name "Flapjack's Dependencies"
maintainer    "Lindsay Holmwood, Jesse Reynolds, Ali Graham, Sarah Kowalik"
homepage      "http://flapjack.io"

package_version = ENV['FLAPJACK_EXPERIMENTAL_PACKAGE_VERSION']
raise "FLAPJACK_EXPERIMENTAL_PACKAGE_VERSION must be set" unless package_version

install_dir   "/opt/flapjack"

build_version  "#{Time.now.strftime('%Y%m%d%H%M%S')}"
build_iteration 1

depend_nokogiri_etc = !(/^(?:0\.9\.|1\.)/.match(package_version).nil?)

# creates required build directories
dependency "preparation"

# flapjack dependencies/components

# version manifest file
dependency "version-manifest"

exclude "\.git*"
exclude "bundler\/git"

override :ruby, version: '2.1.3'
override :rubygems, version: '2.4.8'

dependency "ruby"
dependency "rubygems"
dependency "bundler"
dependency "redis"

if depend_nokogiri_etc
  # Flapjack pre-v2 dependencies
  dependency "yajl"
  dependency "zlib"
  dependency "nokogiri"
end
