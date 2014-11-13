#!/usr/bin/env ruby

# Environment Variables:

# BUILD_REF      - the branch, tag, or commit (on master) to build (Required)
# DISTRO         - only "ubuntu" is currently supported (Optional, Default: "ubuntu")
# DISTRO_RELEASE - the release name, eg "precise" (Optional, Default: "trusy")
# DRY_RUN        - if set, just shows what would be gone (Optiona, Default: nil)

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
require 'fileutils'

dry_run = (ENV["DRY_RUN"].nil? || ENV["DRY_RUN"].empty?) ? false : true
pkg = nil

task :default do
  sh %{rake -T}
end

desc "Build Flapjack packages"
task :build do

  pkg ||= OmnibusFlapjack::Package.new(
    :build_ref      => ENV['BUILD_REF'],
    :distro         => ENV['DISTRO'],
    :distro_release => ENV['DISTRO_RELEASE'],
  )

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
  if system('which usermod')
    puts "Adding user ubuntu to the docker group"
    unless dry_run
      useradd = Mixlib::ShellOut.new("sudo usermod -a -G docker ubuntu")
      unless useradd.run_command
        puts "Error creating the docker user"
      end
    end
  end

  omnibus_cmd = build_omnibus_cmd(pkg)

  docker_cmd = Mixlib::ShellOut.new([
    'docker', 'run', '-t',
    '--attach', 'stdout',
    '--attach', 'stderr',
    '--detach=false',
    '-e', "FLAPJACK_BUILD_REF=#{pkg.build_ref}",
    '-e', "FLAPJACK_EXPERIMENTAL_PACKAGE_VERSION=#{pkg.experimental_package_version}",
    '-e', "FLAPJACK_PACKAGE_VERSION=#{pkg.experimental_package_version}",
    '-e', "FLAPJACK_MAIN_PACKAGE_VERSION=#{pkg.main_package_version}",
    '-e', "DISTRO_RELEASE=#{pkg.distro_release}",
    "flapjack/omnibus-#{pkg.distro}:#{pkg.distro_release}", 'bash', '-l', '-c',
    "\'#{omnibus_cmd}\'"
  ].join(" "), :timeout => 60 * 60)
  puts "Executing: " + docker_cmd.inspect
  unless dry_run
    docker_cmd.run_command
    puts "STDOUT: "
    puts "#{docker_cmd.stdout}"
    puts "STDERR: "
    puts "#{docker_cmd.stderr}"
    if docker_cmd.error?
      puts "ERROR running docker command, exit status is #{docker_cmd.exitstatus}"
      exit 1
    end
    puts "Docker run completed."

    sleep 10 # one time I got "Could not find the file /omnibus-flapjack/pkg in container" and a while later it worked fine

    puts "Retrieving package from the container"
    container_id = `docker ps -l -q`.strip
    Mixlib::ShellOut.new("docker cp #{container_id}:/omnibus-flapjack/pkg .").run_command.error!

    puts "Purging the container"
    Mixlib::ShellOut.new("docker rm #{container_id}").run_command.error!
  end
end

def build_omnibus_cmd(pkg)
  omnibus_cmd = [
    "if [[ -f /opt/rh/ruby193/enable ]]; then source /opt/rh/ruby193/enable; fi",
    "export PATH=$PATH:/usr/local/go/bin",
    "cd omnibus-flapjack",
    "git pull",
    "bundle update omnibus-software",
    "bundle install --binstubs",
    "bin/omnibus build --log-level=info " +
      "--override use_s3_caching:false " +
      "--override use_git_caching:true " +
      "flapjack",
    "cd /omnibus-flapjack/pkg"
  ]

  verify_files = [
    "/opt/flapjack/bin/flapjack",
    "/opt/flapjack/embedded/lib",
    "/opt/flapjack/embedded/bin/redis-server",
    "/etc/init.d/flapjack",
    "/etc/init.d/redis-flapjack",
    "/opt/flapjack/embedded/bin/redis-server",
    "/opt/flapjack/embedded/bin/redis-server",
    "/opt/flapjack/embedded/etc/redis/redis-flapjack.conf",
    ".go$"
  ]

  case pkg.distro
  when 'ubuntu', 'debian'
    # Ubuntu/debian package validation
    omnibus_cmd << [
      "EXPERIMENTAL_FILENAME=$(ls flapjack_#{pkg.experimental_package_version}*.deb)",
      "dpkg -c ${EXPERIMENTAL_FILENAME} > /tmp/flapjack_files"
    ]
    omnibus_cmd << verify_files.map { |f| "grep #{f} /tmp/flapjack_files &>/dev/null" }

    unless pkg.main_package_version.nil?
      omnibus_cmd << [
        "EXPERIMENTAL_FILENAME=$(ls flapjack_#{pkg.experimental_package_version}*.deb)",
        "dpkg-deb -R ${EXPERIMENTAL_FILENAME} repackage",
        "sed -i s@#{pkg.experimental_package_version}-1@#{pkg.main_package_version}@g repackage/DEBIAN/control",
        "sed -i s@#{pkg.experimental_package_version}@#{pkg.main_package_version}@g repackage/opt/flapjack/version-manifest.txt",
        "dpkg-deb -b repackage candidate_${EXPERIMENTAL_FILENAME}"
      ]
      # Validate the newly created main candidate
      omnibus_cmd << [
        "EXPERIMENTAL_FILENAME=$(ls flapjack_#{pkg.experimental_package_version}*.deb)",
        "dpkg -c candidate_${EXPERIMENTAL_FILENAME} > /tmp/flapjack_files"
        ]
      omnibus_cmd << verify_files.map { |f| "grep #{f} /tmp/flapjack_files &>/dev/null" }
    end
  when 'centos'
    # Centos package validation
    omnibus_cmd << [
      "EXPERIMENTAL_FILENAME=$(ls flapjack-#{pkg.experimental_package_version}*.rpm)",
      "rpm -qpl ${EXPERIMENTAL_FILENAME} > /tmp/flapjack_files"
    ]
    omnibus_cmd << verify_files.map { |f| "grep #{f} /tmp/flapjack_files &>/dev/null" }

    unless pkg.main_package_version.nil?
      omnibus_cmd << [
        "EXPERIMENTAL_FILENAME=$(ls flapjack-#{pkg.experimental_package_version}*.rpm)",
        "cp -a ${EXPERIMENTAL_FILENAME} candidate_${EXPERIMENTAL_FILENAME}"
        # "mkdir -p repackage",
        # "cd repackage",
        # "rpm2cpio ../${EXPERIMENTAL_FILENAME} | cpio -idmv",
        # "sed -i s@#{pkg.experimental_package_version}-1@#{pkg.main_package_version}@g opt/flapjack/version-manifest.txt",
        # "cpio -ovF ../candidate_${EXPERIMENTAL_FILENAME}"
      ]
    end
  end
  omnibus_cmd.flatten.join(" && ")
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

  OmnibusFlapjack::Publish.sync_packages_to_local(local_dir, remote_dir)

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

  unless Dir.glob("pkg/candidate_flapjack_#{pkg.experimental_package_version}*").empty?
    puts "Copying candidate package for main to s3"
    Mixlib::ShellOut.new("aws s3 cp pkg/candidate_flapjack#{pkg.major_delim}#{pkg.experimental_package_version}*.deb " +
                         's3://packages.flapjack.io/candidates/ --acl public-read ' +
                         '--region us-east-1').run_command.error!
  end

  OmnibusFlapjack::Publish.release_lock(lockfile)
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

  OmnibusFlapjack::Publish.sync_packages_to_local(local_dir, remote_dir)

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

desc "Build and publish Flapjack packages"
task :build_and_publish => [ :build, :publish ]
