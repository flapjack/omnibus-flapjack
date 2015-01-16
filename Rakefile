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
require 'fileutils'
require 'benchmark'
require 'chronic_duration'

dry_run = (ENV["DRY_RUN"].nil? || ENV["DRY_RUN"].empty?) ? false : true
official_pkg = (ENV["OFFICIAL_FLAPJACK_PACKAGE"].nil? || ENV["OFFICIAL_FLAPJACK_PACKAGE"].empty?) ? false : true
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
    '-e', "FLAPJACK_MAIN_PACKAGE_VERSION=#{pkg.main_package_version}",
    '-e', "DISTRO_RELEASE=#{pkg.distro_release}",
    '-e', "OFFICIAL_FLAPJACK_PACKAGE=#{official_pkg}",
    "-v", "#{Dir.home}/.gnupg:/root/.gnupg",
    "flapjack/omnibus-#{pkg.distro}:#{pkg.distro_release}", 'bash', '-l', '-c',
    "\'#{omnibus_cmd}\'"
  ].join(" "), :timeout => 60 * 60, :live_stream => $stdout)
  puts "Executing: " + docker_cmd.inspect
  unless dry_run
    build_duration = Benchmark.realtime do
      docker_cmd.run_command
    end
    duration_string = ChronicDuration.output(build_duration.round(0), :format => :short)
    puts "STDOUT: "
    puts "#{docker_cmd.stdout}"
    puts "STDERR: "
    puts "#{docker_cmd.stderr}"
    if docker_cmd.error?
      puts "ERROR running docker command, exit status is #{docker_cmd.exitstatus}, duration was #{duration_string}."
      exit 1
    end
    puts "Docker run completed, duration was #{duration_string}."

    sleep 10 # one time I got "Could not find the file /omnibus-flapjack/pkg in container" and a while later it worked fine

    puts "Retrieving package from the container"
    container_id = `docker ps -l -q`.strip
    Mixlib::ShellOut.new("docker cp #{container_id}:/omnibus-flapjack/pkg .").run_command.error!

    Mixlib::ShellOut.new('find pkg -maxdepth 1 -type f -exec md5sum {} \;').run_command.error!

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
    "cp .rpmmacros ~/.rpmmacros",
    "bundle update omnibus",
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
        "dpkg-deb -b repackage candidate_${EXPERIMENTAL_FILENAME}",
        "rm -r repackage"
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

    unless Dir.glob("pkg/candidate_flapjack#{pkg.major_delim}#{pkg.experimental_package_version}*").empty?
      puts "Copying candidate package for main to s3"
      Mixlib::ShellOut.new("aws s3 cp pkg/candidate_flapjack#{pkg.major_delim}#{pkg.experimental_package_version}*.#{pkg.file_suffix} " +
                           's3://packages.flapjack.io/candidates/ --acl public-read ' +
                           '--region us-east-1').run_command.error!
    end

    OmnibusFlapjack::Publish.release_lock(lockfile)
  end
  duration_string = ChronicDuration.output(publish_duration.round(0), :format => :short)
  puts "Publishing completed, duration was #{duration_string}"
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

desc "Test a flapjack package, using vagrant-flapjack"
task :test do
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

  case pkg.distro
  when 'ubuntu'
    test_cmd = [
      "dpkg -i /mnt/omnibus-flapjack/pkg/#{pkg.package_file}",
      # Install a second time to check that the uninstall procedure works
      "dpkg -i /mnt/omnibus-flapjack/pkg/#{pkg.package_file}",
      "apt-get update || true",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y ruby1.9.1-full git nagios3 phantomjs net-tools",
      # Install libraries for nokogiri compilation required during bundle
      "DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential curl libssl-dev libreadline-dev libxslt1-dev libxml2-dev libcurl4-openssl-dev zlib1g-dev libexpat1-dev libicu-dev",
      "echo broker_module=/usr/local/lib/flapjackfeeder.o redis_host=localhost,redis_port=6380 >> /etc/nagios3/nagios.cfg",
      "sed -i -r s/enable_notifications=1/enable_notifications=0/ /etc/nagios3/nagios.cfg",
      "service nagios3 restart"
    ]
    image = "#{pkg.distro}:#{pkg.distro_release}"
  when 'debian'
    test_cmd = [
      "dpkg -i /mnt/omnibus-flapjack/pkg/#{pkg.package_file}",
      # Install a second time to check that the uninstall procedure works
      "dpkg -i /mnt/omnibus-flapjack/pkg/#{pkg.package_file}",
      "apt-get update || true",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y ruby1.9.1-full git nagios3 net-tools ca-certificates wget",
      # No phantomjs package in wheezy yet, only in sid
      "DEBIAN_FRONTEND=noninteractive apt-get install -y libfontconfig1 libexpat1 libfreetype6 libfreetype6 fontconfig-config ucf ttf-dejavu-core ttf-bitstream-vera ttf-freefont fonts-freefont-ttf",
      "wget https://raw.githubusercontent.com/suan/phantomjs-debian/master/phantomjs_1.9.6-0wheezy_amd64.deb",
      "dpkg -i phantomjs_1.9.6-0wheezy_amd64.deb",
      # Install libraries for nokogiri compilation required during bundle
      "DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential curl libssl-dev libreadline-dev libxslt1-dev libxml2-dev libcurl4-openssl-dev zlib1g-dev libexpat1-dev libicu-dev",
      "echo broker_module=/usr/local/lib/flapjackfeeder.o redis_host=localhost,redis_port=6380 >> /etc/nagios3/nagios.cfg",
      "sed -i -r s/enable_notifications=1/enable_notifications=0/ /etc/nagios3/nagios.cfg",
      "service nagios3 restart"
    ]
    image = "#{pkg.distro}:#{pkg.distro_release}"
  when 'centos'
    epel_url = case pkg.distro_release
    when '6'
      "http://download.fedoraproject.org/pub/epel/6/#{pkg.arch}/epel-release-6-8.noarch.rpm"
    when '7'
      "rpm -ivh http://download.fedoraproject.org/pub/epel/7/#{pkg.arch}/e/epel-release-7-2.noarch.rpm"
    end

    test_cmd = [
      "rpm -ivh #{epel_url}",
      "yum install -y centos-release-SCL",
      "yum groupinstall -y \"Development Tools\"",
      "yum install -y ruby193 ruby193-ruby-devel openssl-devel expat-devel perl-ExtUtils-MakeMaker curl-devel tar nagios which",
      "echo \"export PATH=\\${PATH}:/opt/rh/ruby193/root/usr/local/bin\" | tee -a /opt/rh/ruby193/enable",
      "cat /opt/rh/ruby193/enable",
      "source /opt/rh/ruby193/enable",
      "rpm -ivh /mnt/omnibus-flapjack/pkg/#{pkg.package_file}",
      "rpm -ev flapjack",
      "rpm -ivh /mnt/omnibus-flapjack/pkg/#{pkg.package_file}",
      "service redis-flapjack start",
      "service flapjack start",
      "export PATH=\${PATH}:/opt/flapjack/bin",
      "echo broker_module=/usr/local/lib/flapjackfeeder.o redis_host=localhost,redis_port=6380 >> /etc/nagios/nagios.cfg",
      "sed -i -r s/enable_notifications=1/enable_notifications=0/ /etc/nagios/nagios.cfg",
      "service nagios start"
    ]
    image = "#{pkg.distro}:#{pkg.distro}#{pkg.distro_release}"
  end

  test_cmd << [
    "cd /mnt/omnibus-flapjack",
    "gem install bundler --no-ri --no-rdoc",
    "bundle",
    "bundle exec rspec spec/serverspec"
    # "(bundle exec rspec spec/capybara || true)"
  ]

  test_cmd = test_cmd.flatten.join(" && ")

  docker_cmd = Mixlib::ShellOut.new([
    'docker', 'run', '-t',
    '--attach', 'stdout',
    '--attach', 'stderr',
    '--rm',
    "-v #{Dir.pwd}:/mnt/omnibus-flapjack",
    "#{image}", 'bash', '-l', '-c',
    "\'#{test_cmd}\'"
  ].join(" "), :timeout => 60 * 60, :live_stream => $stdout)
  puts "Executing: " + docker_cmd.inspect
  unless dry_run
    test_duration = Benchmark.realtime do
      docker_cmd.run_command
    end
    duration_string = ChronicDuration.output(test_duration.round(0), :format => :short)
    puts "STDOUT: "
    puts "#{docker_cmd.stdout}"
    puts "STDERR: "
    puts "#{docker_cmd.stderr}"
    if docker_cmd.error?
      puts "ERROR running docker command, exit status is #{docker_cmd.exitstatus}, duration was #{duration_string}."
      exit 1
    end
    puts "Test with docker completed, duration was #{duration_string}."
  end
end

desc "Build and test Flapjack packages"
task :build_and_test => [ :build, :test ]

desc "Build, test and publish Flapjack packages"
task :build_and_publish => [ :build, :test, :publish ]
