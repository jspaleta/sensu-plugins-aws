require 'sensu-plugins-aws'
require 'sensu-plugin/check/cli'
require 'aws-sdk-ec2'
require 'rest-client'
require 'json'

class CheckSensuClient
  at_exit do
    @@autorun = false
  end

  def critical(*)
    'triggered critical'
  end

  def warning(*)
    'triggered warning'
  end

  def ok(*)
    'triggered ok'
  end

  def unknown(*)
    'triggered unknown'
  end
end

describe 'CheckSensuClient' do
end
