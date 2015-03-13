#!/usr/bin/env ruby

require 'mixlib/shellout'
require 'benchmark'
require 'chronic_duration'

module OmnibusFlapjack
  module Helpers

    def run_docker (command, opts = {})
      timeout      = opts[:timeout]      || 60 * 60 * 3
      live_stream  = opts[:live_stream]  || $stdout
      max_attempts = opts[:max_attempts] || 10

	    docker_success  = false
	    duration_string = nil

      puts "Executing command: #{command}"

	    (1..max_attempts).each do |attempt|
	      puts "Docker attempt: #{attempt} at #{Time.new}"
	      docker_cmd = Mixlib::ShellOut.new(command,
	                                        :timeout     => timeout,
	                                        :live_stream => live_stream)
	      test_duration = Benchmark.realtime do
	        docker_cmd.run_command
	      end
	      duration_string = ChronicDuration.output(test_duration.round(0), :format => :short)
        puts "docker command completed with exit code: #{docker_cmd.exitstatus}"
	      puts "STDOUT: "
	      puts "#{docker_cmd.stdout}"
	      puts "STDERR: "
	      puts "#{docker_cmd.stderr}"

        if docker_cmd.error?

          if docker_cmd.stderr.match(/Cannot start container.+Error mounting '\/dev\/mapper\/docker/) ||
             docker_cmd.stderr.match(/Cannot start container.+Error getting container .+ from driver.*devicemapper/)
            docker_name = docker_cmd_string.match(/--name (\S+)/)[1]
            puts "Deleting container and retrying the docker command"
            Mixlib::ShellOut.new("docker rm #{docker_name}").run_command
            next
          end

          puts "Error running docker command, exit status is #{docker_cmd.exitstatus}, duration was #{duration_string}."
          exit 1
        end
        docker_success = true
        break
	    end

      unless docker_success
        puts "Unable to successfully run the docker build command after #{max_attempts} attempts. Exiting!"
        exit 1
      end

      puts "Docker run completed, duration was #{duration_string}."
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

  end
end
