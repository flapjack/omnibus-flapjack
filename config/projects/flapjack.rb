
name          "flapjack"
friendly_name "Flapjack"
maintainer    "Lindsay Holmwood, Jesse Reynolds, Ali Graham, Sarah Kowalik"
homepage      "http://flapjack.io"

if ENV['OFFICIAL_FLAPJACK_PACKAGE'] == 'true'
  package :rpm do
    # This is the same key as used for the Debian repository signing, which uses a blank passphrase.
    # This field requires a value to be activated, but is otherwise unused.
    signing_passphrase '1234'
  end
end

install_dir   "/opt/flapjack"

version = ENV['FLAPJACK_BUILD_REF']
package_version = ENV['FLAPJACK_EXPERIMENTAL_PACKAGE_VERSION']
raise "FLAPJACK_BUILD_REF must be set" unless version
raise "FLAPJACK_EXPERIMENTAL_PACKAGE_VERSION must be set" unless package_version

build_version package_version
build_iteration 1

depend_nokogiri_etc = !(/^(?:0\.9\.|1\.)/.match(package_version).nil?)

# creates required build directories
dependency "preparation"

# flapjack dependencies/components
# dependency "somedep"

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

dependency "flapjack"
