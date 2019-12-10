#! /usr/bin/env ruby
#
# elb-metrics
#
# DESCRIPTION:
#   Gets kinesis metrics from CloudWatch and puts them in Graphite for longer term storage
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#   gem: sensu-plugin-aws
#   gem: time
#
# USAGE:
#   #YELLOW
#
# NOTES:
#   Returns a set of Kinesis statistics for a given stream name.  You can specify any valid Kinesis metric type, see
#   https://docs.aws.amazon.com/streams/latest/dev/monitoring-with-cloudwatch.html
#
# LICENSE:
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/metric/cli'
require 'aws-sdk'
require 'sensu-plugins-aws'
require 'time'

class KinesisMetrics < Sensu::Plugin::Metric::CLI::Graphite
  include Common
  option :streamname,
         description: 'Name of the Kinesis stream (required)',
         short: '-n STREAM_NAME',
         long: '--name STREAM_NAME'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric (default: aws.kinesis)',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'aws.kinesis'

  option :fetch_age,
         description: 'How long ago (in seconds) to fetch metrics for (default: 60)',
         short: '-f AGE',
         long: '--fetch_age',
         default: 60,
         proc: proc(&:to_i)

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--region REGION',
         description: 'AWS Region (default: us-east-1)',
         default: ENV['AWS_REGION']

  option :end_time,
         short:       '-t T',
         long:        '--end-time TIME',
         default:     Time.now,
         proc:        proc { |a| Time.parse a },
         description: 'CloudWatch metric statistics end time (default: Time.now)'

  option :period,
         short:       '-p N',
         long:        '--period SECONDS',
         default:     60,
         proc:        proc(&:to_i),
         description: 'CloudWatch metric statistics period (default: 60)'

  def cloud_watch
    @cloud_watch = Aws::CloudWatch::Client.new
  end

  def cloud_watch_metric(metric_name, stats, stream_name)
    request = {
      namespace: 'AWS/Kinesis',
      metric_name: metric_name,
      dimensions: [
        {
          name: 'StreamName',
          value: stream_name
        }
      ],
      start_time: config[:end_time] - config[:fetch_age] - config[:period],
      end_time: config[:end_time] - config[:fetch_age],

      period: config[:period],
      statistics: stats,
      unit: config[:unit]
    }
    cloud_watch.get_metric_statistics(request)
  end

  def underscore(camel_cased_word)
    camel_cased_word.to_s.gsub(/::/, '/').gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').tr('-', '_').downcase
  end

  def print_statistics(stream_name, statistics, metrics)
    result = {}
    timestamp = {}
    static_value = {}
    metrics.each do |key|
      r = cloud_watch_metric(key, statistics, stream_name)
      unless r[:datapoints][0].nil?
        statistics.each do |static|
          keys = if config[:scheme] == ''
                   []
                 else
                   [config[:scheme]]
                 end
          keys.concat [stream_name, underscore(key), underscore(static)]
          metric_key = keys.join('.')
          static_value[metric_key] = static
          result[metric_key] = r[:datapoints][0][underscore(static)]
          timestamp[metric_key] = r[:datapoints][0][:timestamp]
        end
      end
    end
    result.each do |key, value|
      output key.to_s, value, timestamp[key].to_i
    end
  end

  def run
    stats = %w[Minimum Maximum Average Sum SampleCount]
    metrics = [
      'GetRecords.Bytes',
      'GetRecords.IteratorAgeMilliseconds',
      'GetRecords.Latency',
      'GetRecords.Records',
      'GetRecords.Success',
      'IncomingBytes',
      'IncomingRecords',
      'PutRecord.Bytes',
      'PutRecord.Latency',
      'PutRecord.Success',
      'PutRecords.Bytes',
      'PutRecords.Latency',
      'PutRecords.Records',
      'PutRecords.Success',
      'ReadProvisionedThroughputExceeded',
      'SubscribeToShard.RateExceeded',
      'SubscribeToShard.Success',
      'SubscribeToShardEvent.Bytes',
      'SubscribeToShardEvent.MillisBehindLatest',
      'SubscribeToShardEvent.Records',
      'SubscribeToShardEvent.Success',
      'WriteProvisionedThroughputExceeded'
    ]

    begin
      print_statistics(config[:streamname], stats, metrics)
      ok
    end
  end
end
