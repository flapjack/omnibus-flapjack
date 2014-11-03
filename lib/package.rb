#!/usr/bin/env ruby

class Package
  attr_reader :build_ref, :package_file, :truth_from_filename

  def distro
    return @distro if @distro
    if (@package_file && !@package_file.empty?)
      @distro = case
      when @package_file.match(/wheezy/)
        'debian'
      when @package_file.match(/(precise|trusty)/)
        'ubuntu'
      when @package_file.match(/rpm$/)
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
      case distro
      when 'ubuntu' || 'debian'
        experimental_package_version.split(minor_delim).last
      when 'centos'
        @package_file.split('.')[-3].split('el')[1]
      end
    end
  end

  def file_suffix
    if @truth_from_filename
      return @package_file.split('.').last
    end
    case distro
    when 'ubuntu', 'debian'
      'deb'
    when 'centos'
      'rpm'
    else
      nil
    end
  end

  def major_delim
    return @major_delim ||= ['ubuntu', 'debian'].include?(distro) ? '_' : '-'
  end

  def minor_delim
    return @minor_delim ||= ['ubuntu', 'debian'].include?(distro) ? '-' : '_'
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
      version_with_date = experimental_package_version.split(@minor_delim).first
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

  def package_version
    @package_version ||= if truth_from_filename
      package_name, package_version = package_file.split(major_delim)
      package_version.gsub(/#{minor_delim}1$/, '')
    else
      nil
    end
  end

  def experimental_package_version
    @experimental_package_version ||= if truth_from_filename
      package_version
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
        "#{first}#{minor_delim}0.#{timestamp}#{second}"
      end
    end
  end

  def main_package_version
    # Only build a candidate package for main if the version isn't an RC (contains an alpha)
    return nil if experimental_package_version =~ /[a-zA-Z]/
    case distro
    when 'ubuntu', 'debian'
      @main_package_version ||= "#{version}#{major_delim}#{distro_release}"
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
