#!/usr/bin/env ruby

# Environment Variables:

# BUILD_REF                 - the branch, tag, or commit (on master) to build (Required)
# DISTRO                    - only "ubuntu" is currently supported (Optional, Default: "ubuntu")
# DISTRO_RELEASE            - the release name, eg "precise" (Optional, Default: "trusy")
# DRY_RUN                   - if set, just shows what would be gone (Optiona, Default: nil)
# OFFICIAL_FLAPJACK_PACKAGE - if true, assuming that the Flapjack Signing Key is on the system, and sign the rpm package

# eg:
#   bundle
#   BUILD_REF=v1.0.0 DISTRO=ubuntu DISTRO_RELEASE=trusty bundle exec rake build_and_publish
#   BUILD_REF=v1.0.0 DISTRO=centos DISTRO_RELEASE=6 bundle exec rake build_and_publish
#   PACKAGE_FILE=flapjack-1.2.0_0.rc220141024003313-1.el6.x86_64.rpm bundle exec rake publish
#   PACKAGE_FILE=flapjack-1.2.0_0.rc220141024003313-1.el6.x86_64.rpm bundle exec rake promote
#
# pkg/flapjack_1.1.0~+20141003112645-master-trusty-1_amd64.deb
# pkg/flapjack_1.1.0~+20141003112645-master-centos-6-1_amd64.rpm
$:.push(File.expand_path(File.join(__FILE__, '..', 'lib')))
require 'mixlib/shellout'
require 'omnibus-flapjack/package'
require 'omnibus-flapjack/publish'
require 'omnibus-flapjack/helpers'
require 'fileutils'
require 'benchmark'
require 'chronic_duration'

dry_run = (ENV["DRY_RUN"].nil? || ENV["DRY_RUN"].empty?) ? false : true
official_pkg = (ENV["OFFICIAL_FLAPJACK_PACKAGE"].nil? || ENV["OFFICIAL_FLAPJACK_PACKAGE"].empty?) ? false : true
pkg = nil
if ENV['packagecloud_user']
  packagecloud_credentials = {
    :username => ENV['packagecloud_user'],
    :token    => ENV['packagecloud_token']
  }
end

task :default do
  sh %{rake -T}
end

desc "Build Flapjack packages"
task :build do
  begin
    pkg ||= OmnibusFlapjack::Package.new(
      :build_ref      => ENV['BUILD_REF'],
      :distro         => ENV['DISTRO'],
      :distro_release => ENV['DISTRO_RELEASE'],
    )
  rescue ArgumentError
    puts "To build, please set the following environment variables as appropriate:"
    puts "  BUILD_REF"
    puts "  DISTRO"
    puts "  DISTRO_RELEASE"
    exit 1
  end

  puts "distro:               #{pkg.distro}"
  puts "distro_release:       #{pkg.distro_release}"
  puts "build_ref:            #{pkg.build_ref}"
  puts "file_suffix:          #{pkg.file_suffix}"
  puts "major_delim:          #{pkg.major_delim}"
  puts "minor_delim:          #{pkg.minor_delim}"
  puts "version:              #{pkg.version}"
  puts "package_version:      #{pkg.experimental_package_version}"
  puts pkg.main_package_version.nil? ? "Not building candidate for main - version contains an alpha" : "main_package_version: #{pkg.main_package_version}"
  puts

  puts "Starting Docker container..."

  # ensure the 'ubuntu' user is in the docker group
  if system('type usermod')
    puts "Adding user ubuntu to the docker group"
    unless dry_run
      useradd = Mixlib::ShellOut.new("sudo usermod -a -G docker ubuntu")
      unless useradd.run_command
        puts "Error creating the docker user"
      end
    end
  end

  omnibus_cmd = OmnibusFlapjack::Helpers.build_omnibus_cmd(pkg)

  container_name = "flapjack-build-#{pkg.distro_release}"

  docker_cmd_string = [
    'docker', 'run', '-t',
    '--attach', 'stdout',
    '--attach', 'stderr',
    '--detach=false',
    '--name', container_name,
    '-e', "FLAPJACK_BUILD_REF=#{pkg.build_ref}",
    '-e', "FLAPJACK_EXPERIMENTAL_PACKAGE_VERSION=#{pkg.experimental_package_version}",
    '-e', "FLAPJACK_MAIN_PACKAGE_VERSION=#{pkg.main_package_version}",
    '-e', "DISTRO_RELEASE=#{pkg.distro_release}",
    '-e', "OFFICIAL_FLAPJACK_PACKAGE=#{official_pkg}",
    "-v", "#{Dir.home}/.gnupg:/root/.gnupg",
    "flapjack/omnibus-#{pkg.distro}:#{pkg.distro_release}", 'bash', '-l', '-c',
    "\'#{omnibus_cmd}\'"
  ].join(" ")
  puts "Executing: " + docker_cmd_string
  unless dry_run
    OmnibusFlapjack::Helpers.run_docker(docker_cmd_string)

    sleep 10 # one time I got "Could not find the file /omnibus-flapjack/pkg in container" and a while later it worked fine

    puts "Retrieving package from the container"
    Mixlib::ShellOut.new("docker cp #{container_name}:/omnibus-flapjack/pkg .").run_command.error!

    Mixlib::ShellOut.new('find pkg -maxdepth 1 -type f -exec md5sum {} \;').run_command.error!

    puts "Purging the container #{container_name}"
    Mixlib::ShellOut.new("docker rm #{container_name}").run_command

    puts "Uploading #{pkg.package_file} packages to http://packages.flapjack.io/tmp/#{pkg.package_file}"
    Mixlib::ShellOut.new("aws s3 cp pkg/#{pkg.package_file} s3://packages.flapjack.io/tmp/ --acl public-read " +
                         "--region us-east-1 2>&1", :live_stream => $stdout).run_command.error!

    unless Dir.glob("pkg/candidate_flapjack#{pkg.major_delim}#{pkg.experimental_package_version}*").empty?
      puts "Copying candidate package for main to s3"
      Mixlib::ShellOut.new("aws s3 cp pkg/candidate_flapjack#{pkg.major_delim}#{pkg.experimental_package_version}*.#{pkg.file_suffix} " +
                           's3://packages.flapjack.io/candidates/ --acl public-read ' +
                           '--region us-east-1').run_command.error!
    end
  end
end

desc "Publish a Flapjack package (to experimental)"
task :publish do
  pkg ||= OmnibusFlapjack::Package.new(
    :package_file => ENV['PACKAGE_FILE']
  )

  puts "distro:          #{pkg.distro}"
  puts "distro_release:  #{pkg.distro_release}"
  puts "major_version:   #{pkg.major_version}"
  puts "package_version: #{pkg.experimental_package_version}"
  puts "file_suffix:     #{pkg.file_suffix}"
  puts "major_delim:     #{pkg.major_delim}"
  puts "minor_delim:     #{pkg.minor_delim}"

  raise "distro cannot be determined" unless pkg.distro
  raise "distro_release cannot be determined" unless pkg.distro_release
  raise "major_version cannot be determined" unless pkg.major_version
  raise "package_version cannot be determined" unless pkg.experimental_package_version

  if dry_run
    puts "Ending early due to DRY_RUN being set"
    exit 1
  end

  unless official_pkg
    puts "This is not an official Flapjack build, therefore a publish can't be done.  If this is incorrect, export OFFICIAL_FLAPJACK_PACKAGE=true"
    exit 2
  end

  start_dir = FileUtils.pwd

  case pkg.distro
  when 'ubuntu', 'debian'
    local_dir   = 'aptly'
    remote_dir  = 's3://packages.flapjack.io/aptly'
    lockfile    = 'flapjack_upload_deb.lock'

    puts "Creating aptly.conf"
    # Create aptly config file
    aptly_config = <<-eos
      {
        "rootDir": "#{start_dir}/#{local_dir}",
        "downloadConcurrency": 4,
        "downloadSpeedLimit": 0,
        "architectures": [],
        "dependencyFollowSuggests": false,
        "dependencyFollowRecommends": false,
        "dependencyFollowAllVariants": false,
        "dependencyFollowSource": false,
        "gpgDisableSign": false,
        "gpgDisableVerify": false,
        "downloadSourcePackages": false,
        "S3PublishEndpoints": {}
      }
    eos
    File.write('aptly.conf', aptly_config)
  when 'centos'
    local_dir   = 'createrepo'
    remote_dir  = 's3://packages.flapjack.io/rpm'
    lockfile    = 'flapjack_upload_rpm.lock'
  end

  OmnibusFlapjack::Publish.get_lock(lockfile)

  publish_duration = Benchmark.realtime do
    OmnibusFlapjack::Publish.sync_packages_to_local(local_dir, remote_dir)

    OmnibusFlapjack::Publish.add_to_packagecloud(pkg, packagecloud_credentials) if packagecloud_credentials

    case pkg.distro
    when 'ubuntu', 'debian'
      OmnibusFlapjack::Publish.add_to_deb_repo(pkg)

      OmnibusFlapjack::Publish.create_indexes('aptly/public', '../../create_directory_listings')

      OmnibusFlapjack::Publish.sync_packages_to_remote('aptly/public', 's3://packages.flapjack.io/deb')

    when 'centos'
      OmnibusFlapjack::Publish.add_to_rpm_repo(pkg)

      OmnibusFlapjack::Publish.create_indexes(local_dir, '../create_directory_listings')
    else
      puts "Error: I don't know how to publish for distro #{pkg.distro}"
      exit 1
    end

    OmnibusFlapjack::Publish.sync_packages_to_remote(local_dir, remote_dir)

    OmnibusFlapjack::Publish.release_lock(lockfile)
  end
  duration_string = ChronicDuration.output(publish_duration.round(0), :format => :short)
  puts "Publishing completed, duration was #{duration_string}"

  puts "Removing #{pkg.package_file} from packages.flapjack.io/tmp"
  Mixlib::ShellOut.new("aws s3 rm s3://packages.flapjack.io/tmp/#{pkg.package_file} " +
                       "--region us-east-1 2>&1", :live_stream => $stdout).run_command.error!
end

desc "Update directory indexes for the deb repo"
task :update_indexes_deb do
  local_dir   = 'deb'
  remote_dir  = 's3://packages.flapjack.io/deb'
  lockfile    = 'flapjack_upload_deb.lock'

  update_indexes_duration = Benchmark.realtime do
    OmnibusFlapjack::Publish.get_lock(lockfile)
    OmnibusFlapjack::Publish.sync_packages_to_local(local_dir, remote_dir)
    OmnibusFlapjack::Publish.create_indexes(local_dir, '../create_directory_listings')
    OmnibusFlapjack::Publish.sync_packages_to_remote(local_dir, remote_dir, :dry_run => dry_run)
    OmnibusFlapjack::Publish.release_lock(lockfile)
  end
  duration_string = ChronicDuration.output(update_indexes_duration.round(0), :format => :short)
  puts "deb repo indexes updating completed, duration was #{duration_string}"
end

desc "Update directory indexes for the rpm repo"
task :update_indexes_rpm do
  local_dir   = 'createrepo'
  remote_dir  = 's3://packages.flapjack.io/rpm'
  lockfile    = 'flapjack_upload_rpm.lock'

  update_indexes_duration = Benchmark.realtime do
    OmnibusFlapjack::Publish.get_lock(lockfile)
    OmnibusFlapjack::Publish.sync_packages_to_local(local_dir, remote_dir)
    OmnibusFlapjack::Publish.create_indexes(local_dir, '../create_directory_listings')
    OmnibusFlapjack::Publish.sync_packages_to_remote(local_dir, remote_dir, :dry_run => dry_run)
    OmnibusFlapjack::Publish.release_lock(lockfile)
  end
  duration_string = ChronicDuration.output(update_indexes_duration.round(0), :format => :short)
  puts "rpm repo indexes updating completed, duration was #{duration_string}"
end

desc "Promote a published Flapjack package (from experimental to main)"
task :promote do
  pkg ||= OmnibusFlapjack::Package.new(
    :package_file => ENV['PACKAGE_FILE']
  )

  puts "distro:          #{pkg.distro}"
  puts "distro_release:  #{pkg.distro_release}"
  puts "major_version:   #{pkg.major_version}"
  puts "package_file:    #{pkg.package_file}"
  puts "version:         #{pkg.version}"
  puts "package_version: #{pkg.experimental_package_version}"
  puts "file_suffix:     #{pkg.file_suffix}"
  puts "major_delim:     #{pkg.major_delim}"
  puts "minor_delim:     #{pkg.minor_delim}"

  raise "distro cannot be determined" unless pkg.distro
  raise "distro_release cannot be determined" unless pkg.distro_release
  raise "major_version cannot be determined" unless pkg.major_version
  raise "package_version cannot be determined" unless pkg.experimental_package_version

  if dry_run
    puts "Ending early due to DRY_RUN being set"
    exit 1
  end

  unless official_pkg
    puts "This is not an official Flapjack build, therefore a promote can't be done.  If this is incorrect, export OFFICIAL_FLAPJACK_PACKAGE=true"
    exit 2
  end

  start_dir = FileUtils.pwd

  case pkg.distro
  when 'ubuntu', 'debian'
    local_dir   = 'aptly'
    remote_dir  = 's3://packages.flapjack.io/aptly'
    lockfile    = 'flapjack_upload_deb.lock'

    puts "Creating aptly.conf"
    # Create aptly config file
    aptly_config = <<-eos
      {
        "rootDir": "#{start_dir}/#{local_dir}",
        "downloadConcurrency": 4,
        "downloadSpeedLimit": 0,
        "architectures": [],
        "dependencyFollowSuggests": false,
        "dependencyFollowRecommends": false,
        "dependencyFollowAllVariants": false,
        "dependencyFollowSource": false,
        "gpgDisableSign": false,
        "gpgDisableVerify": false,
        "downloadSourcePackages": false,
        "S3PublishEndpoints": {}
      }
    eos
    File.write('aptly.conf', aptly_config)
  when 'centos'
    local_dir   = 'createrepo'
    remote_dir  = 's3://packages.flapjack.io/rpm'
    lockfile    = 'flapjack_upload_rpm.lock'
  end

  OmnibusFlapjack::Publish.get_lock(lockfile)

  filename = ENV['PACKAGE_FILE']
  if File.file?("pkg/candidate_#{filename}")
    puts "Package was found locally"
  else
    puts "Package was not found locally.  Downloading from S3"
    FileUtils.mkdir_p("pkg")
    Mixlib::ShellOut.new("aws s3 cp s3://packages.flapjack.io/candidates/candidate_#{filename} pkg/. " +
                         "--acl public-read --region us-east-1").run_command.error!
  end

  FileUtils.copy("pkg/candidate_#{filename}", "pkg/#{pkg.main_filename}")
  puts "Main package file is at pkg/#{pkg.main_filename}"

  Mixlib::ShellOut.new('find pkg -maxdepth 1 -type f -exec md5sum {} \;').run_command.error!

  OmnibusFlapjack::Publish.sync_packages_to_local(local_dir, remote_dir)

  OmnibusFlapjack::Publish.add_to_packagecloud(pkg, packagecloud_credentials, 'main') if packagecloud_credentials

  case pkg.distro
  when 'ubuntu', 'debian'
    OmnibusFlapjack::Publish.add_to_deb_repo(pkg, 'main')

    OmnibusFlapjack::Publish.create_indexes('aptly/public', '../../create_directory_listings')

    OmnibusFlapjack::Publish.sync_packages_to_remote('aptly/public', 's3://packages.flapjack.io/deb')

  when 'centos'
    OmnibusFlapjack::Publish.add_to_rpm_repo(pkg, 'main')

    OmnibusFlapjack::Publish.create_indexes(local_dir, '../create_directory_listings')
  else
    puts "Error: I don't know how to publish for distro #{pkg.distro}"
    exit 1
  end

  OmnibusFlapjack::Publish.sync_packages_to_remote(local_dir, remote_dir)

  puts "Removing the old S3 package"
  Mixlib::ShellOut.new("aws s3 rm s3://packages.flapjack.io/candidates/candidate_#{filename} " +
                       "--region us-east-1").run_command.error!

  OmnibusFlapjack::Publish.release_lock(lockfile)
end

desc "Test a flapjack package, using docker"
task :test do
  packages = []
  pkg ||= OmnibusFlapjack::Package.new(
    :package_file => ENV['PACKAGE_FILE']
  )
  packages << pkg

  main_pkg_filename = pkg.package_file.gsub('flapjack', 'candidate_flapjack')
  if File.file?(File.join('pkg', main_pkg_filename))
    packages << OmnibusFlapjack::Package.new(
      :package_file => main_pkg_filename
    )
  end

  packages.each do |pkg|
    puts "distro:          #{pkg.distro}"
    puts "distro_release:  #{pkg.distro_release}"
    puts "major_version:   #{pkg.major_version}"
    puts "package_version: #{pkg.experimental_package_version}"
    puts "file_suffix:     #{pkg.file_suffix}"
    puts "major_delim:     #{pkg.major_delim}"
    puts "minor_delim:     #{pkg.minor_delim}"
    puts "package_file:    #{pkg.package_file}"
    puts

    raise "distro cannot be determined" unless pkg.distro
    raise "distro_release cannot be determined" unless pkg.distro_release
    raise "major_version cannot be determined" unless pkg.major_version
    raise "package_version cannot be determined" unless pkg.experimental_package_version

    options = {
      :distro  => pkg.distro,
      :distro_release => pkg.distro_release,
      :arch    => pkg.arch,
      :dry_run => dry_run
    }
    options[:install_cmd] = case pkg.distro
    when 'ubuntu', 'debian'
      [
        "dpkg -i /mnt/omnibus-flapjack/pkg/#{pkg.package_file}",
        # Install a second time to check that the uninstall procedure works
        "dpkg -i /mnt/omnibus-flapjack/pkg/#{pkg.package_file}"
      ]
    when 'centos'
      [
        "rpm -ivh /mnt/omnibus-flapjack/pkg/#{pkg.package_file}",
        "service redis-flapjack start",
        "service flapjack start",
        "export PATH=\${PATH}:/opt/flapjack/bin",
        "rpm -ev flapjack",
        "rpm -ivh /mnt/omnibus-flapjack/pkg/#{pkg.package_file}",
        "service redis-flapjack start",
        "service flapjack start"
      ]
    end
    OmnibusFlapjack::Helpers.run_tests_in_docker(options)
  end
end

desc "Test a flapjack package from the repository, using docker"
task :post_publish_test do
  # Choose distro & release
  # Clone vagrant flapjack
  # Mount vagrant-flapjack in docker container
  # Start up Docker
  # Install puppet
  # Run puppet from vagrant-flapjack
  # Run serverspec
  # Run capybara on supported OSes

  distro         = ENV['DISTRO']
  distro_release = ENV['DISTRO_RELEASE']
  component      = ENV['FLAPJACK_COMPONENT']
  if distro == 'centos'
    component = component == 'main' ? 'flapjack' : 'flapjack-experimental'
  end
  arch = distro == 'centos' ? 'x86_64' : 'amd64'

  unless dry_run
    if File.exist?('vagrant-flapjack/Vagrantfile')
      Mixlib::ShellOut.new("cd vagrant-flapjack && git checkout test-deps-in-puppet && git pull && cd -", :live_stream => $stdout).run_command.error!
    else
      # When docker mounts a directory that doesn't exist, it creates an empty directory.  Here, we remove the empty directory, and get the real vagrant-flapjack
      Mixlib::ShellOut.new("rm -rf vagrant-flapjack; git clone https://github.com/flapjack/vagrant-flapjack.git", :live_stream => $stdout).run_command.error!
    end
  end

  install_cmd = "gem install puppet librarian-puppet && " +
                "FACTER_flapjack_component='#{component}' " +
                "FACTER_flapjack_major_version='v1' " +
                "FACTER_test_mode='true' FACTER_tutorial_mode='false' FACTER_with_sensu='false' " +
                "puppet apply --modulepath /mnt/vagrant-flapjack/dist/modules:/etc/puppet/modules " +
                "--manifestdir /mnt/vagrant-flapjack/dist/manifests " +
                "/mnt/vagrant-flapjack/dist/manifests/site.pp"

  options = {
    :distro  => distro,
    :distro_release => distro_release,
    :arch    => arch,
    :dry_run => dry_run,
    :install_cmd => install_cmd
  }
  options[:extra_tests] = 'bundle exec rspec spec/capybara' unless distro == 'centos'
  OmnibusFlapjack::Helpers.run_tests_in_docker(options)
end

desc "Build and test Flapjack packages"
task :build_and_test => [ :build, :test ]

desc "Build, test and publish Flapjack packages"
task :build_and_publish => [ :build, :test, :publish ]
