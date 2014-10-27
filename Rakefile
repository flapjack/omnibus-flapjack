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
#
# pkg/flapjack_1.1.0~+20141003112645-master-trusty-1_amd64.deb
# pkg/flapjack_1.1.0~+20141003112645-master-centos-6-1_amd64.rpm

require 'mixlib/shellout'

dry_run = (ENV["DRY_RUN"].nil? || ENV["DRY_RUN"].empty?) ? false : true
pkg = nil

task :default do
  sh %{rake -T}
end

class Package

  attr_reader :build_ref, :package_file, :truth_from_filename

  def distro
    return @distro if @distro
    if (@package_file && !@package_file.empty?)
      @distro = case @package_file.split('.').last
      when 'deb'
        'ubuntu'
      when 'rpm'
        'centos'
      else
        nil
      end
    else
      return nil
    end
  end

  def distro_release
    @distro_release ||= if truth_from_filename
      package_version.split(minor_delim).last
    end
  end

  def file_suffix
    if @truth_from_filename
      return @package_file.split('.').last
    end
    case distro
    when 'ubuntu'
      'deb'
    when 'centos'
      'rpm'
    else
      nil
    end
  end

  def major_delim
    return @major_delim ||= ['ubuntu'].include?(distro) ? '_' : '-'
  end

  def minor_delim
    return @minor_delim ||= ['ubuntu'].include?(distro) ? '-' : '_'
  end

  def version
    return @version if @version
    if truth_from_filename
      raise RuntimeError 'version from filename is unsupported'
    else
      version_url = "https://raw.githubusercontent.com/flapjack/flapjack/" +
                    "#{build_ref}/lib/flapjack/version.rb"
      version_cmd = Mixlib::ShellOut.new("wget -qO - #{version_url} | grep VERSION | cut -d '\"' -f 2")
      version_cmd.run_command
      version_cmd.error!
      version = version_cmd.stdout.strip
      unless version.length > 0
        raise "Incorrect build_ref.  Tags should be specified as 'v1.0.0rc3'"
      end
      @version = version
    end
  end

  # Use v<major release> as a repo prefix, unless it's the 0.9 series.
  def major_version
    @major_version ||= if truth_from_filename
      version_with_date = package_version.split(@minor_delim).first
      major, minor = version_with_date.split('.')
      major == '0' ? "0.#{minor}" : "v#{major}"
    else
      major, minor = version.split('.')
      major == '0' ? "0.#{minor}" : "v#{major}"
    end
  end

  def timestamp
    @timestamp ||= if truth_from_filename
      raise RuntimeError 'timestamp from filename unsupported'
    else
      Time.now.utc.strftime('%Y%m%d%H%M%S')
    end
  end

  def experimental_package_version
    @package_version ||= if truth_from_filename
      package_name, package_version = package_file.split(major_delim)
      package_version.gsub(/#{minor_delim}1$/, '')
    else
      first, second = version.match(/^([0-9.]*)([a-z0-9.]*)$/).captures
      case @distro
      when 'ubuntu', 'debian'
        if second.empty?
          # If we get a version that isn't an RC (contains an alpha), make
          # the package version~+date-ref-release-1 so that it sorts above RCs
          # ie, insert a + before the timestamp
          "#{first}~+#{timestamp}#{minor_delim}#{build_ref}#{minor_delim}#{distro_release}"
        else
          "#{first}~#{second}~#{timestamp}#{minor_delim}#{build_ref}#{minor_delim}#{distro_release}"
        end
      when 'centos'
        "#{first}#{minor_delim}0.#{second}#{timestamp}"
      end
    end
  end

  def main_package_version
    # Only build a candidate package for main if the version isn't an RC (contains an alpha)
    return nil if version =~ /[a-zA-Z]/
    case distro
    when 'ubuntu', 'debian'
      @main_package_version ||= "#{version}#{minor_delim}#{distro_release}"
    when 'centos'
      # flapjack-1.2.0-1.el6.x86_64.rpm
      @main_package_version ||= version
    end
  end

  def initialize(options)
    @build_ref      = options[:build_ref]
    @distro         = options[:distro]
    @distro_release = options[:distro_release]
    @package_file   = options[:package_file]
    @truth_from_filename = @package_file && !@package_file.nil?
  end
end

desc "Build Flapjack packages"
task :build do

  pkg ||= Package.new(
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
      puts "ERROR running docker command, exit code is #{docker_cmd.exitstatus}"
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

  unless pkg.main_package_version.nil?
    case pkg.distro
    when 'ubuntu', 'debian'
      debian_build_main = [
        "EXPERIMENTAL_FILENAME=$(ls flapjack_#{pkg.experimental_package_version}*.deb)",
        "dpkg-deb -R ${EXPERIMENTAL_FILENAME} repackage",
        "sed -i s@#{pkg.experimental_package_version}-1@#{pkg.main_package_version}@g repackage/DEBIAN/control",
        "sed -i s@#{pkg.experimental_package_version}@#{pkg.main_package_version}@g repackage/opt/flapjack/version-manifest.txt",
        "dpkg-deb -b repackage candidate_${EXPERIMENTAL_FILENAME}"
      ]
      omnibus_cmd.push(debian_build_main).flatten.join(" && ")
    when 'centos'
      centos_build_main = [
        "ls"
      #TODO: write me
      ]
      omnibus_cmd.push(centos_build_main).flatten.join(" && ")
    end
  end
end

desc "Publish a Flapjack package (to experimental)"
task :publish do
  # flapjack_1.1.0~+20141003112645-master-trusty-1_amd64.deb
  # flapjack-1.2.0~rc1~20141017011950_master_6-1.el6.x86_64.rpm

  pkg ||= Package.new(
    :package_file   => ENV['PACKAGE_FILE']
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

  case pkg.distro
  when 'ubuntu', 'debian'
      local_dir   = 'aptly'
      remote_dir  = 's3://packages.flapjack.io/aptly'
      lockfile    = 'flapjack_upload_deb.lock'

      puts "Creating aptly.conf"
      # Create aptly config file
      aptly_config = <<-eos
        {
          "rootDir": "#{FileUtils.pwd}/#{local_dir}",
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
    remote_dir  = 's3://packages.flapjack.io/rpmtest'
    lockfile    = 'flapjack_upload_rpm.lock'

    # TODO: install & configure createrepo
  end

  get_lock(lockfile)

  sync_packages_to_local(local_dir, remote_dir)

  case pkg.distro
  when 'ubuntu', 'debian'
    puts "Checking aptly db for errors"
    Mixlib::ShellOut.new("aptly -config aptly.conf db recover").run_command.error!
    Mixlib::ShellOut.new("aptly -config aptly.conf db cleanup").run_command.error!

    puts "Creating all components for the distro release if they don't exist"

    valid_components = ['main', 'experimental']

    valid_components.each do |component|
      if Mixlib::ShellOut.new("aptly -config=aptly.conf repo show " +
                              "flapjack-#{pkg.major_version}-#{pkg.distro_release}-#{component}"
                              ).run_command.error?
        Mixlib::ShellOut.new("aptly -config=aptly.conf repo create -distribution #{pkg.distro_release} " +
                             "-architectures='i386,amd64' -component=#{component} " +
                             "flapjack-#{pkg.major_version}-#{pkg.distro_release}-#{component}"
                             ).run_command.error!
      end
    end

    puts "Adding pkg/flapjack_#{pkg.experimental_package_version}*.deb to the " +
         "flapjack-#{pkg.major_version}-#{pkg.distro_release}-experimental repo"
    Mixlib::ShellOut.new("aptly -config=aptly.conf repo add " +
                         "flapjack-#{pkg.major_version}-#{pkg.distro_release}-experimental " +
                         "pkg/flapjack_#{pkg.experimental_package_version}*.deb").run_command.error!


    puts "Attempting the first publish for all components of the major version " +
         "of the given distro release"
    publish_cmd = 'aptly -config=aptly.conf publish repo -architectures="i386,amd64" ' +
                  '-gpg-key="803709B6" -component=, '
    valid_components.each do |component|
      publish_cmd += "flapjack-#{pkg.major_version}-#{pkg.distro_release}-#{component} "
    end
    publish_cmd += " #{pkg.major_version}"
    if Mixlib::ShellOut.new(publish_cmd).run_command.error?
      puts "Repository already published, attempting an update"
      # Aptly checks the inode number to determine if packages are the same.
      # As we sync from S3, our inode numbers change, so identical packages are deemed different.
      Mixlib::ShellOut.new('aptly -config=aptly.conf -gpg-key="803709B6" -force-overwrite=true ' +
                           "publish update #{pkg.distro_release} #{pkg.major_version}").run_command.error!
    end

    create_indexes('aptly/public', '../../create_directory_listings')

    sync_packages_to_remote('aptly/public', 's3://packages.flapjack.io/deb')

  when 'centos'
    upload_rpm_cmd = Mixlib::ShellOut.new("aws s3 cp pkg s3://packages.flapjack.io/rpm/ --recursive")
    if upload_rpm_cmd.run_command.error?
      puts "Error: Failed to upload package file to s3"
      upload_rpm_cmd.error!
    end

    create_indexes(local_dir, '../create_directory_listings')
  else
    puts "Error: I don't know how to publish for distro #{pkg.distro}"
    exit 1
  end

  sync_packages_to_remote(local_dir, remote_dir)

  if %(ubuntu debian).include?(pkg.distro)
    # FIXME: limit to main
    puts "Copying candidate package for main to s3"
    Mixlib::ShellOut.new("aws s3 cp pkg/candidate_flapjack_#{pkg.experimental_package_version}*.deb " +
                         's3://packages.flapjack.io/candidates/ --acl public-read ' +
                         '--region us-east-1').run_command.error!
  end

  release_lock(lockfile)
end

#FIXME: generate list_script automatically
def create_indexes(local_dir, list_script)
  puts "Creating directory index files for published packages"
  indexes = Mixlib::ShellOut.new("cd #{local_dir} && #{list_script} .")
  if indexes.run_command.error?
    puts "Warning: Directory indexes failed to be created"
    puts indexes.inspect
  end
end

def get_lock(lockfile)
  # Attempt to get lock file from S3
  obtained_lock = false
  (1..360).each do |i|
    if Mixlib::ShellOut.new("aws s3 cp s3://packages.flapjack.io/#{lockfile} #{lockfile}" +
      "--acl public-read --region us-east-1").run_command.error?
      obtained_lock = true
      break
    end
    puts "Could not get flapjack upload lock, someone else is updating the repository: #{i}"
    sleep 10
  end

  unless obtained_lock
    puts "Error: timed out trying to get #{lockfile}"
    exit 4
  end

  puts "Starting package upload"
  Mixlib::ShellOut.new("touch #{lockfile}").run_command.error!
  Mixlib::ShellOut.new("aws s3 cp #{lockfile} s3://packages.flapjack.io/#{lockfile} --acl public-read " +
                       "--region us-east-1").run_command.error!
end

def release_lock(lockfile)
  puts "Removing package upload lockfile"
  if Mixlib::ShellOut.new("aws s3 rm s3://packages.flapjack.io/#{lockfile} --region us-east-1").run_command.error?
    puts "Failed to remove lockfile - please remove s3://packages.flapjack.io/#{lockfile} manually"
    exit 5
  end
end

def sync_packages_to_local(local_dir, remote_dir)
  FileUtils.mkdir_p(local_dir)

  puts "Syncing down #{remote_dir} to #{local_dir}"
  Mixlib::ShellOut.new("aws s3 sync #{remote_dir} #{local_dir} --delete " +
                       "--acl public-read --region us-east-1").run_command.error!
end

def sync_packages_to_remote(local_dir, remote_dir)
  puts "Syncing #{local_dir} up to #{remote_dir}"
  Mixlib::ShellOut.new("aws s3 sync #{local_dir} #{remote_dir} " +
                       "--delete --acl public-read --region us-east-1").run_command.error!
end

desc "Promote a published Flapjack package (from experimental to main)"
task :promote do
end

desc "Build and publish Flapjack packages"
task :build_and_publish => [ :build, :publish ]
