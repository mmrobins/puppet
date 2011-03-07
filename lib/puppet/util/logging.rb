# A module to make logging a bit easier.
require 'puppet/util/log'

module Puppet::Util::Logging

  @@indent_text = ''
  def send_log(level, message)
    Puppet::Util::Log.create({:level => level, :source => log_source, :message => message}.merge(log_metadata))
  end

  # Create a method for each log level.
  Puppet::Util::Log.eachlevel do |level|
    next if level.to_s == 'debug'
    define_method(level) do |args|
      args = args.join(" ") if args.is_a?(Array)
      send_log(level, @@indent_text + args)
    end
  end

  def deprecation_warning(message)
    $deprecation_warnings ||= Hash.new(0)
    if $deprecation_warnings.length < 100 and ($deprecation_warnings[message] += 1) == 1
      warning message
    end
  end

  def clear_deprecation_warnings
    $deprecation_warnings.clear if $deprecation_warnings
  end

  def debug(message)
    assert_that("debug message should only ever be string") { message.is_a?(String) }

    if block_given? && Puppet::Util::Log.level == :debug
      time_started = Time.now
      msg = @@indent_text + "Start (#{time_started.strftime('%H:%M:%S')}) " + message
      send_log(:debug, msg)

      @@indent_text += '|   '
      begin
        return_value = yield
      ensure
        @@indent_text = @@indent_text.slice(0..-5)
        elapsed = Time.now - time_started
        end_time = elapsed > 1 ? Time.now.strftime('%H:%M:%S') + ' ' : ''
        timing_info = "Finished (#{end_time}Time elapsed #{elapsed}) "
        send_log(:debug, @@indent_text + timing_info + message)
      end
      return return_value
    elsif block_given?
      yield
    else
      send_log(:debug, @@indent_text + message)
    end
  rescue
    raise
  end

  private

  def is_resource?
    defined?(Puppet::Type) && is_a?(Puppet::Type)
  end

  def is_resource_parameter?
    defined?(Puppet::Parameter) && is_a?(Puppet::Parameter)
  end

  def log_metadata
    [:file, :line, :tags].inject({}) do |result, attr|
      result[attr] = send(attr) if respond_to?(attr)
      result
    end
  end

  def log_source
    # We need to guard the existence of the constants, since this module is used by the base Puppet module.
    (is_resource? or is_resource_parameter?) and respond_to?(:path) and return path.to_s
    to_s
  end
end
