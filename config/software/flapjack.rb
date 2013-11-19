name "flapjack"

version = '0.7.33'
version "v#{version}"

dependency "ruby"
dependency "rubygems"
dependency "bundler"

source :git => "git://github.com/flpjck/flapjack.git"

relative_path "flapjack"

build do
  # Install all dependencies
  bundle "install --path=#{install_dir}/embedded/service/gem"

  # Build + install the gem
  bundle "exec rake build"
  gem [ "install pkg/flapjack*.gem",
        "--bindir #{install_dir}/bin",
        "--no-rdoc --no-ri" ].join(" ")
end


