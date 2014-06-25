name "flapjack"

build_ref = ENV['FLAPJACK_BUILD_TAG'] ? "v#{ENV['FLAPJACK_BUILD_TAG']}" : "HEAD"
default_version build_ref

dependency "ruby"
dependency "rubygems"
dependency "bundler"
dependency "nokogiri"

source :git => "https://github.com/flapjack/flapjack"

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

