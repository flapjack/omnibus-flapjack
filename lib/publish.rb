#!/usr/bin/env ruby

class Publish
  class << self
    #FIXME: generate list_script automatically
    def create_indexes(local_dir, list_script)
      unless File.directory?(local_dir)
        puts "Error, local_dir does not exist (#{local_dir}) pwd: #{FileUtils.pwd}"
        return
      end
      Dir.chdir(local_dir) do
        unless File.file?(list_script)
          puts "Error, list_script does not exist (#{list_script}) pwd: #{FileUtils.pwd}"
          return
        end
        puts "Creating directory index files for published packages"
        indexes = Mixlib::ShellOut.new("#{list_script} .")
        if indexes.run_command.error?
          puts "Warning: Directory indexes failed to be created"
          puts indexes.inspect
        end
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
      unless File.directory?(local_dir)
        puts "Error, local_dir does not exist (#{local_dir}) pwd: #{FileUtils.pwd}"
        return false
      end
      puts "Syncing #{local_dir} up to #{remote_dir}"
      Mixlib::ShellOut.new("aws s3 sync #{local_dir} #{remote_dir} " +
                           "--delete --acl public-read --region us-east-1").run_command.error!
    end

    def add_to_deb_repo(pkg, component = 'experimental')
      puts "Checking aptly db for errors"
      Mixlib::ShellOut.new("aptly -config aptly.conf db recover").run_command.error!
      Mixlib::ShellOut.new("aptly -config aptly.conf db cleanup").run_command.error!

      puts "Creating all components for the distro release if they don't exist"

      valid_components = ['main', 'experimental']

      valid_components.each do |comp|
        if Mixlib::ShellOut.new("aptly -config=aptly.conf repo show " +
                                "flapjack-#{pkg.major_version}-#{pkg.distro_release}-#{comp}"
                                ).run_command.error?
          Mixlib::ShellOut.new("aptly -config=aptly.conf repo create -distribution #{pkg.distro_release} " +
                               "-architectures='i386,amd64' -component=#{comp} " +
                               "flapjack-#{pkg.major_version}-#{pkg.distro_release}-#{comp}"
                               ).run_command.error!
        end
      end

      # FIXME: wrong filename
      puts "Adding pkg/flapjack_#{pkg.experimental_package_version}*.deb to the " +
           "flapjack-#{pkg.major_version}-#{pkg.distro_release}-#{component} repo"
      Mixlib::ShellOut.new("aptly -config=aptly.conf repo add " +
                           "flapjack-#{pkg.major_version}-#{pkg.distro_release}-#{component} " +
                           "pkg/flapjack_#{pkg.experimental_package_version}*.deb").run_command.error!

      puts "Attempting the first publish for all components of the major version " +
           "of the given distro release"
      publish_cmd = 'aptly -config=aptly.conf publish repo -architectures="i386,amd64" ' +
                    '-gpg-key="803709B6" -component=, '
      valid_components.each do |comp|
        publish_cmd += "flapjack-#{pkg.major_version}-#{pkg.distro_release}-#{comp} "
      end
      publish_cmd += " #{pkg.major_version}"
      if Mixlib::ShellOut.new(publish_cmd).run_command.error?
        puts "Repository already published, attempting an update"
        # Aptly checks the inode number to determine if packages are the same.
        # As we sync from S3, our inode numbers change, so identical packages are deemed different.
        Mixlib::ShellOut.new('aptly -config=aptly.conf -gpg-key="803709B6" -force-overwrite=true ' +
                             "publish update #{pkg.distro_release} #{pkg.major_version}").run_command.error!
      end
    end

    def add_to_rpm_repo(pkg, component = 'experimental')
      releases = %w(6)
      arches = %w(i386 x86_64)
      flapjack_version = %w(v1)
      components = %w(flapjack flapjack-experimental)

      base_dir = 'createrepo'
      FileUtils.mkdir_p(base_dir)

      puts "Creating rpm repositories"
      arches.each do |arch|
        releases.each do |version|
          flapjack_version.each do |fl_version|
            components.each do |comp|
              # eg v1/flapjack/centos/6/x86_64
              local_dir = File.join(base_dir, fl_version, comp, 'centos', version, arch)

              unless File.exist?(local_dir)
                puts "New RPM repo: #{local_dir}"
                FileUtils.mkdir_p local_dir
                Dir.chdir(local_dir) do
                  createrepo_cmd = Mixlib::ShellOut.new('createrepo .')
                  unless createrepo_cmd.run_command
                    puts "Error running 'createrepo .', exit status is #{createrepo_cmd.exitstatus}"
                    puts "PWD:    #{FileUtils.pwd}"
                    puts "STDOUT: #{createrepo_cmd.stdout}"
                    puts "STDERR: #{createrepo_cmd.stderr}"
                    exit 1
                  end
                end
              end
            end
          end
        end
      end

      component = case component
      when 'experimental'
        'flapjack-experimental'
      when 'main'
        'flapjack'
      else
        raise 'Unknown component for upload'
      end
      # FIXME: don't hardcode arch
      name = [ pkg.major_version, component, 'centos', pkg.distro_release, 'x86_64' ]

      # FIXME: wrong filename for main packages
      puts "Adding pkg/flapjack-#{pkg.experimental_package_version}*.rpm to the #{name.join('-')} repo"
      Mixlib::ShellOut.new("cp pkg/flapjack-#{pkg.experimental_package_version}*.rpm #{File.join(base_dir, *name)}/.").run_command.error!

      puts "Updating #{name.join('-')} repo"
      Dir.chdir(File.join(base_dir, *name)) do
        Mixlib::ShellOut.new('createrepo .').run_command.error!
      end
    end
  end # class << self
end
