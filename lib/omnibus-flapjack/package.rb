#!/usr/bin/env ruby

require 'mixlib/shellout'
require 'open-uri'

module OmnibusFlapjack
  class Package
    attr_reader :build_ref, :truth_from_filename

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
        when 'ubuntu', 'debian'
          experimental_package_version.split(minor_delim).last.split('-').first
        when 'centos'
          @package_file.gsub(/^candidate_/, '').split('_')[1].split('.')[-2].match(/el(.+)/)[1]
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
      @major_delim ||= ['ubuntu', 'debian'].include?(distro) ? '_' : '-'
    end

    def minor_delim
      @minor_delim ||= ['ubuntu', 'debian'].include?(distro) ? '~' : '_'
    end

    def version
      return @version if @version
      @version = if truth_from_filename
        case distro
        when 'ubuntu', 'debian'
          # flapjack_1.2.0~rc2~20141104062643~v1.2.0rc2~wheezy-1_amd64.deb
          # flapjack_1.2.0~+20141107130330~v1.2.0~wheezy-1_amd64.deb
          a = @package_file.gsub(/^candidate_/, '').split(major_delim)[1].split('~')
          a.length > 4 ? "#{a[0]}#{a[1]}" : a[0]
        when 'centos'
          # flapjack-1.4.0_0.20150312130042rc1.el6-1.el6.x86_64.rpm
          simple_version, date_and_crap = @package_file.gsub(/^candidate_/, '').split(major_delim)[1].split(minor_delim)
          _, addendum = date_and_crap.split('.')[1].split(/\d{14}/)
          "#{simple_version}#{addendum}"
        end
      else
        version_url = "https://raw.githubusercontent.com/flapjack/flapjack/" +
                      "#{build_ref}/lib/flapjack/version.rb"
        open(version_url) {|f|
          f.each_line {|line|
            next unless line =~ /VERSION.*=.*"(.*)"/
            @version = $1
          }
        }
        unless version.length > 0
          raise "Incorrect build_ref.  Tags should be specified as 'v1.0.0rc3'"
        end
        @version
      end
    end

    # we're only building on 64 bit platforms currently...
    def arch
      return @arch if @arch
      @arch = case distro
      when 'ubuntu', 'debian'
        'amd64'
      when 'centos'
        'x86_64'
      end
    end

    def package_file
      @package_file ||= case distro
      when 'ubuntu', 'debian'
        "flapjack_#{experimental_package_version}-1_#{arch}.#{file_suffix}"
      when 'centos'
        "flapjack-#{experimental_package_version}-1.el#{distro_release}.#{arch}.#{file_suffix}"
      end
    end

    def main_filename
      return @main_filename if @main_filename
      return nil unless version.match(/^[\d\.]+$/)
      @main_filename = case distro
      when 'ubuntu', 'debian'
        "flapjack_#{version}~#{distro_release}_#{arch}.#{file_suffix}"
      when 'centos'
        "flapjack-#{version}_0.el#{distro_release}.#{arch}.#{file_suffix}"
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
        package_name, package_version = package_file.gsub(/^candidate_/, '').split(major_delim)
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
          build_ref_clean = build_ref.sub(/\//, '.')
          if second.empty?
            # If we get a version that isn't an RC (contains an alpha), make
            # the package version~+date-ref-release-1 so that it sorts above RCs
            # ie, insert a + before the timestamp
            "#{first}~+#{timestamp}#{minor_delim}#{build_ref_clean}#{minor_delim}#{distro_release}"
          else
            "#{first}~#{second}~#{timestamp}#{minor_delim}#{build_ref_clean}#{minor_delim}#{distro_release}"
          end
        when 'centos'
          "#{first}#{minor_delim}0.#{timestamp}#{second}.el#{distro_release}"
        end
      end
    end

    def main_package_version
      # Only build a candidate package for main if the version isn't an RC (contains an alpha)
      return nil if version =~ /[a-zA-Z]/
      @main_package_version ||= case distro
      when 'ubuntu', 'debian'
        "#{version}#{minor_delim}#{distro_release}"
      when 'centos'
        "#{version}.el#{distro_release}"
      end
    end

    def initialize(options)
      @build_ref      = options[:build_ref]
      @distro         = options[:distro]
      @distro_release = options[:distro_release]
      @package_file   = options[:package_file]
      unless (@build_ref && @distro && @distro_release) || @package_file
        raise ArgumentError, "cannot initialize package"
      end
      @truth_from_filename = @package_file && !@package_file.nil?
    end
  end
end
