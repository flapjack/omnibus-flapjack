
name          "flapjack-dependencies"
friendly_name "Flapjack's Dependencies"
maintainer    "Lindsay Holmwood, Jesse Reynolds, Ali Graham"
homepage      "http://flapjack.io"

install_dir   "/opt/flapjack"

build_version  "#{Time.now.strftime('%Y%m%d%H%M%S')}"
build_iteration 1

# creates required build directories
dependency "preparation"

# flapjack dependencies/components
# dependency "somedep"

# version manifest file
dependency "version-manifest"

exclude "\.git*"
exclude "bundler\/git"

override :ruby, version: '2.1.1'

dependency "ruby"
dependency "rubygems"
dependency "bundler"
dependency "redis"
dependency "yajl"
dependency "zlib"
dependency "nokogiri"

