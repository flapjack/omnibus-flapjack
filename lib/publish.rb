#!/usr/bin/env ruby

class Publish
  class << self
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
  end # class << self
end
