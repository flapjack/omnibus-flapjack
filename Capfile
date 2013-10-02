#!/usr/bin/env ruby

require 'pathname'
$: << Pathname.new(__FILE__).parent.to_s

require 'rubygems'
require 'bundler/setup'

# don't load default Cap tasks, just load the ones we've defined
load    'config/deploy'

# load up locally defined tasks
Dir['config/tasks/**/*.rb'].each do |task|
  load(task)
end
