require 'spec_helper'
require 'omnibus-flapjack/package'

describe 'Package' do
  describe 'Truth from Filename' do
    describe 'Ubuntu' do


      it 'extracts data from the filename of a final ubuntu package filename' do
        filename = 'flapjack_1.2.0~+20141107124706-v1.2.0-trusty-1_amd64.deb'
        pkg = OmnibusFlapjack::Package.new(:package_file => filename)
        expect(pkg.package_file).to eq(filename)
        expect(pkg.version).to eq('1.2.0')
        expect(pkg.distro).to eq('ubuntu')
        expect(pkg.distro_release).to eq('trusty')
        expect(pkg.file_suffix).to eq('deb')
        expect(pkg.main_filename).to eq('flapjack_1.2.0-trusty_amd64.deb')
      end

      it 'extracts data from the filename of a release candidate ubuntu package filename' do
        filename = 'flapjack_1.2.0~rc2~20141017025853-v1.2.0rc2-trusty-1_amd64.deb'
        pkg = OmnibusFlapjack::Package.new(:package_file => filename)
        expect(pkg.version).to eq('1.2.0rc2')
        expect(pkg.distro).to eq('ubuntu')
        expect(pkg.distro_release).to eq('trusty')
        expect(pkg.main_filename).to eq(nil)
      end

      it 'extracts data from the filename of a development ubuntu package filename' do
        filename = 'flapjack_1.2.0~+20141003112645-master-trusty-1_amd64.deb'
        pkg = OmnibusFlapjack::Package.new(:package_file => filename)
        expect(pkg.version).to eq('1.2.0')
        expect(pkg.distro).to eq('ubuntu')
        expect(pkg.distro_release).to eq('trusty')
        expect(pkg.main_filename).to eq(nil)
      end
    end

    describe 'Debian' do
      it 'extracts data from the filename of a final package filename' do
        filename = 'flapjack_1.2.0~+20141107130330-v1.2.0-wheezy-1_amd64.deb'
        pkg = OmnibusFlapjack::Package.new(:package_file => filename)
        expect(pkg.version).to eq('1.2.0')
        expect(pkg.distro).to eq('debian')
        expect(pkg.distro_release).to eq('wheezy')
        expect(pkg.file_suffix).to eq('deb')
        expect(pkg.main_filename).to eq('flapjack_1.2.0-wheezy_amd64.deb')
      end

      it 'extracts data from the filename of a release candidate package filename' do
        filename = 'flapjack_1.2.0~rc2~20141104062643-v1.2.0rc2-wheezy-1_amd64.deb'
        pkg = OmnibusFlapjack::Package.new(:package_file => filename)
        expect(pkg.version).to eq('1.2.0rc2')
        expect(pkg.distro).to eq('debian')
        expect(pkg.distro_release).to eq('wheezy')
        expect(pkg.main_filename).to eq(nil)
      end

      it 'extracts data from the filename of a development ubuntu package filename' do
        filename = 'flapjack_1.2.0~+20141106050911-master-wheezy-1_amd64.deb'
        pkg = OmnibusFlapjack::Package.new(:package_file => filename)
        expect(pkg.version).to eq('1.2.0')
        expect(pkg.distro).to eq('debian')
        expect(pkg.distro_release).to eq('wheezy')
        expect(pkg.main_filename).to eq(nil)
      end
    end

    describe 'Centos' do
      it 'extracts data from the filename of a final package filename' do
        filename = 'flapjack-1.2.0_0.20141107131800-1.el6.x86_64.rpm'
        pkg = OmnibusFlapjack::Package.new(:package_file => filename)
        expect(pkg.version).to eq('1.2.0')
        expect(pkg.distro).to eq('centos')
        expect(pkg.distro_release).to eq('6')
        expect(pkg.file_suffix).to eq('rpm')
        expect(pkg.main_filename).to eq('flapjack-1.2.0_1.el6.x86_64.rpm')
      end

      it 'extracts data from the filename of a release candidate package filename' do
        filename = 'flapjack-1.2.0_0.20141106052252rc2-1.el6.x86_64.rpm'
        pkg = OmnibusFlapjack::Package.new(:package_file => filename)
        expect(pkg.version).to eq('1.2.0rc2')
        expect(pkg.distro).to eq('centos')
        expect(pkg.distro_release).to eq('6')
      end

    end
  end
end
