#!/usr/bin/env ruby

require 'fileutils'

releases = %w(6 7)
arches = %w(i386 x86_64)
flapjack_version = %w(v1)
components = %w(flapjack flapjack-experimental)

base_dir = 'createrepo'
list_dir = FileUtils.mkdir_p File.join(base_dir, 'lists')

# https://packages.flapjack.io/lists/v1-flapjack-centos-6

arches.each do |arch|
  releases.each do |version|
    flapjack_version.each do |fl_version|
      components.each do |component|
        # eg v1/flapjack/centos/6/x86_64
        package_url = File.join(fl_version, component, 'centos', version, arch)

        # Create yum repos
        FileUtils.mkdir_p File.join(base_dir, package_url)
        Dir.chdir(File.join(base_dir, package_url)) do
          system('createrepo .')
        end

        # Build yum repository config file for user systems
        repo_filename = [fl_version, component, 'centos', version].join('-')
        File.open(File.join(list_dir, repo_filename), 'w') do |f|
          f.puts "[#{repo_filename}]"
          f.puts "Name=#{repo_filename}"
          f.puts "baseurl=http://packages.flapjack.io/rpm/#{package_url}/$basearch"
          f.puts "enabled=1"
        end
      end
    end
  end
end
