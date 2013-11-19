
name       "flapjack"
maintainer "Lindsay Holmwood <lindsay@holmwood.id.au>"
homepage   "http://flapjack.io"

replaces        "flapjack"
install_path    "/opt/flapjack"

version = '0.7.34'
build_version   "#{version}+#{Time.now.strftime('%Y%m%d%H%M%S')}"
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
dependency "redis"
dependency "yajl"
dependency "zlib"
dependency "nokogiri"
dependency "flapjack"
