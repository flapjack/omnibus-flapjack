require 'serverspec_spec_helper'

def flapjack_major_version
  return @flapjack_major_version unless @flapjack_major_version.nil?
  @flapjack_major_version = ENV['FLAPJACK_MAJOR_VERSION'] || '-1'
  @flapjack_major_version
end

describe service('redis-flapjack'), :if => os[:family] == 'ubuntu' do
  it { should be_enabled }
end
describe service('redis-flapjack'), :if => os[:family] == 'redhat' do
  it { should_not be_enabled }
end

describe service('flapjack'), :if => os[:family] == 'ubuntu' do
  it { should be_enabled }
end
describe service('flapjack'), :if => os[:family] == 'redhat' do
  it { should_not be_enabled }
end

describe package('flapjack') do
  it { should be_installed }
end

describe service('flapjack') do

  it { should be_running }
end

describe process("redis-server") do
  it { should be_running }
  its(:args) { should match /0.0.0.0:6380/ }
end

describe process("flapjack") do
  it { should be_running }
  its(:args) do
    if ['0', '1'].include?(flapjack_major_version)
      should match /\/opt\/flapjack\/bin\/flapjack server start/
    else
      should match /\/opt\/flapjack\/bin\/flapjack server/
    end
  end
end

describe port(3080) do
  it { should be_listening }
end
describe port(3081) do
  it { should be_listening }
end
describe port(6380) do
  it { should be_listening }
end

describe command('/opt/flapjack/bin/flapjack receiver httpbroker --help') do
  channel = ['0', '1'].include?(flapjack_major_version) ? :stdout : :stderr
  its(channel) { should match /port/ }
  its(channel) { should match /server/ }
  its(channel) { should match /database/ }
  its(channel) { should match /interval/ }
end

describe file("/etc/flapjack/flapjack_config.#{['0', '1'].include?(flapjack_major_version) ? 'yaml' : 'toml'}") do
  it { should be_file }
  its(:content) { should match /pagerduty/ }
end

describe file('/usr/local/lib/flapjackfeeder.o') do
  it { should be_file }
end

if ['0', '1'].include?(flapjack_major_version)
  describe file('/var/log/flapjack/flapjack.log') do
    it { should be_file }
    it { should be_mode 644 }
  end

  describe file('/var/log/flapjack/notification.log') do
    it { should be_file }
    it { should be_mode 644 }
  end
end

describe file('/var/log/flapjack/jsonapi_access.log') do
  it { should be_file }
  it { should be_mode 644 }
end

describe file('/var/log/flapjack/redis-flapjack.log') do
  it { should be_file }
  it { should be_mode 644 }
end

describe file('/var/log/flapjack/web_access.log') do
  it { should be_file }
  it { should be_mode 644 }
end
