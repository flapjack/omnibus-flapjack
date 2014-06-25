
name          "flapjack"
friendly_name "Flapjack"
maintainer    "Lindsay Holmwood, Jesse Reynolds, Ali Graham"
homepage      "http://flapjack.io"

install_path   "/opt/flapjack"

version = ENV['FLAPJACK_BUILD_TAG']
build_version  "#{version}+#{Time.now.strftime('%Y%m%d%H%M%S')}"
build_iteration 1

# creates required build directories
dependency "preparation"

# flapjack dependencies/components
# dependency "somedep"

# version manifest file
dependency "version-manifest"

exclude "\.git*"
exclude "bundler\/git"

dependency "ruby"
dependency "rubygems"
dependency "bundler"
dependency "redis"
dependency "yajl"
dependency "zlib"
dependency "nokogiri"
dependency "flapjack"

