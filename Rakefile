#!/usr/bin/env ruby

require 'colorize'
require 'tmpdir'

task :default => 'deploy:push'

repo          = 'git@github.com:flapjack/packages.flapjack.io.git'
cache_pointer = '.flapjack-package-cache'

# FIXME(auxesis): this is all a little dirty right now, and doesn't work end to end
namespace :deploy do
  task :cache_repo do
    if File.exist?(cache_pointer)
      @cache_path = File.read(cache_pointer).strip
      puts "Using cached packages.flapjack.io repo at #{@cache_path}".green
    else
      repo        = 'git@github.com:flapjack/packages.flapjack.io.git'
      @cache_path = Dir.mktmpdir
      puts "Cloning packages.flapjack.io repo to #{@cache_path}".green
      command = "git clone #{repo} #{@cache_path}"
      sh(command)

      File.open(cache_pointer, 'w') {|f| f << @cache_path }
    end
  end

  task :push => [ :has_s3cmd?, :cache_repo ] do
    source_root = File.expand_path(File.join(__FILE__, '..', 'pkg'))
    packages    = Dir.glob(File.join(source_root, '*.deb')).sort_by {|pkg|
      timestamp = File.basename(pkg)[/\+(\d+)\-/,1].to_i
      Time.at(timestamp.to_i)
    }

    source    = packages.last

    command = "reprepro -b #{@cache_path}/deb includedeb precise #{source}"
    sh(command)

    #command = "s3cmd --verbose --acl-public --delete-removed --rexclude '^\.git.*$' sync . s3://packages.flapjack.io/"
    #sh(command)
  end

  task :has_s3cmd? do
    if not system("which s3cmd", :err => :out, :out => '/dev/null')
      puts "s3cmd isn't installed".red
      abort
    end
  end
end
