#!/usr/bin/env ruby

# Environment Variables:

# BUILD_REF      - the branch, tag, or commit (on master) to build (Required)
# DISTRO         - only "ubuntu" is currently supported (Optional, Default: "ubuntu")
# DISTRO_RELEASE - the release name, eg "precise" (Optional, Default: "trusy")

# eg:
#   bundle
#   BUILD_REF=v1.0.0 DISTRO=ubuntu DISTRO_RELEASE=trusty bundle exec rake build_and_publish

require 'mixlib/shellout'

unless (ENV["BUILD_REF"] && ! ENV["BUILD_REF"].empty?)
  raise "BUILD_REF must be set to the branch, tag, or commit to build"
end
build_ref      = ENV["BUILD_REF"]
distro         = ENV["DISTRO"].empty? ? "ubuntu" : ENV["DISTRO"]
distro_release = ENV["DISTRO_RELEASE"].empty? ? "trusty" : ENV["DISTRO_RELEASE"]

date             = Time.now.utc.strftime('%Y%m%d%H%M%S')
valid_components = ['main', 'experimental']

task :default do
  sh %{rake -T}
end

desc "Build Flapjack packages"
task :build do

  puts "build_ref: #{build_ref}"
  puts "distro: #{distro}"
  puts "distro_release: #{distro_release}"

  # ensure the 'ubuntu' user is in the docker group
  if system('which usermod')
    puts "Adding user ubuntu to the docker group"
    useradd = Mixlib::ShellOut.new("sudo usermod -a -G docker ubuntu")
    unless useradd.run
      puts "Error creating the docker user"
    end
  end

  puts "Determining build attributes ..."
  version_url = "https://raw.githubusercontent.com/flapjack/flapjack/#{build_ref}/lib/flapjack/version.rb"
  #version = Mixlib::ShellOut.new("wget -qO - #{version_url} | grep VERSION | cut -d '\"' -f 2").error!.stdout.strip
  version_cmd = Mixlib::ShellOut.new("wget -qO - #{version_url} | grep VERSION | cut -d '\"' -f 2")
  version_cmd.run_command
  version_cmd.error!
  version = version_cmd.stdout.strip

  unless version.length > 0
    raise "Incorrect build_ref.  Tags should be specified as 'v1.0.0rc3'"
  end
  puts "version: #{version}"

  # Use v<major release> as a repo prefix, unless it's the 0.9 series.
  major, minor, patch = version.split('.', 3)
  major_version = major == '0' ? "0.#{minor}" : "v#{major}"
  puts "major_version: #{major_version}"

  #put a ~ separator in before any alpha parts of the version string, eg "1.0.0rc3" -> "1.0.0~rc3"
  full_version = version.gsub(/^([0-9.]*)([a-z0-9.]*)$/) {$2.empty? ? $1 : "#{$1}~#{$2}"}
  package_version = case
  when full_version =~ /[a-zA-Z]/
    "#{full_version}~#{date}-#{build_ref}-#{distro_release}"
  else
    # If we get a version that isn't an RC (contains an alpha), make package_version full_version~+date-ref-release-1 so that it sorts above RCs
    "#{full_version}~+#{date}-#{build_ref}-#{distro_release}"
  end
  main_package_version = "#{major}.#{minor}.#{patch}-#{distro_release}"

  puts
  puts "full_version: #{full_version}"
  puts "package_version: #{package_version}"
  puts "main_package_version: #{main_package_version}"
  puts
  puts "Starting Docker container..."

  omnibus_cmd = [
    "export PATH=$PATH:/usr/local/go/bin",
    "cd omnibus-flapjack",
    "git pull",
    "bundle update omnibus-software",
    "bundle install --binstubs",
    "bin/omnibus build --log-level=info " +
      "--override use_s3_caching:false " +
      "--override use_git_caching:true " +
      "flapjack",
    "cd /omnibus-flapjack/pkg",
    "EXPERIMENTAL_FILENAME=$(ls flapjack_#{package_version}*.deb)",
    "dpkg-deb -R ${EXPERIMENTAL_FILENAME} repackage",
    "sed -i s##{package_version}-1##{main_package_version}#g repackage/DEBIAN/control",
    "sed -i s##{package_version}##{main_package_version}#g repackage/opt/flapjack/version-manifest.txt",
    "dpkg-deb -b repackage candidate_${EXPERIMENTAL_FILENAME}"].join(" && ")

  docker_cmd = Mixlib::ShellOut.new([
    'docker', 'run', '-t', 
    '--attach', 'stdout',
    '--attach', 'stderr',
    '--detach=false',
    '-e', "FLAPJACK_BUILD_REF=#{build_ref}",
    '-e', "FLAPJACK_PACKAGE_VERSION=#{package_version}",
    '-e', "FLAPJACK_MAIN_PACKAGE_VERSION=#{main_package_version}",
    '-e', "DISTRO_RELEASE=#{distro_release}",
    "flapjack/omnibus-ubuntu:#{distro_release}", 'bash', '-c',
    "\'#{omnibus_cmd}\'"
  ].join(" "), :timeout => 60 * 60)
  docker_cmd.run_command
  docker_cmd.error!
  puts "Docker run completed."
  sleep 10 # one time I got "Could not find the file /omnibus-flapjack/pkg in container" and a while later it worked fine
  puts "Retrieving package from the container"
  container_id = `docker ps -l -q`.strip
  retrieve_pkg_cmd = Mixlib::ShellOut.new("docker cp #{container_id}:/omnibus-flapjack/pkg .")
  retrieve_pkg_cmd.run_command
  retrieve_pkg_cmd.error!

  #puts "Purging the container"
  #Mixlib::Shellout.new("docker rm #{container_id}").error!

end


desc "Publish Flapjack packages"
task :publish do

end

desc "Build and publish Flapjack packages"
task :build_and_publish => [ :build, :publish ]

