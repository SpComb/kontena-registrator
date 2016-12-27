require 'celluloid'

require 'kontena/logging'

# Start/stop services from configuration udpates
class Kontena::Registrator::Manager
  include Celluloid
  include Kontena::Logging

  def initialize(configuration_observable, services, service_opts, start: true)
    @configuration_observable = configuration_observable
    @services = services
    @service_opts = service_opts

    self.start if start
  end

  def start
    self.async.run
  end

  def apply(config_state)
    logger.debug "apply..."

    # sync up sevices
    config_state.each do |policy, config|
      logger.debug "apply policy=#{policy} with config=#{config.to_s}: #{config.to_json}"

      if self[policy, config]
        self.reload(policy, config)
      else
        self.create(policy, config)
      end
    end

    # sync down services
    self.each do |policy, config_key|
      unless config_state[policy, config_key]
        self.remove(policy, config_key)
      end
    end
  end

  def run
    @configuration_observable.observe do |config_state|
      apply(config_state)
    end
  end

  # Manager API

  # TODO: trap_exit

  # Get Service for policy, with optional config
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config policy configuration object
  # @return [Service]
  def [](policy, config = nil)
    @services[[policy, config ? config.to_s : nil]]
  end

  # @yield [policy, config_key]
  def each(&block)
    @services.each do |key, supervisor|
      policy, config_key = key
      yield policy, config_key
    end
  end

  # Is the service running?
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config [nil, Kontena::Registrator::Policy::Config]
  def status(policy, config = nil)
    self[policy, config]
  end

  # Supervise a new Service for the given Policy and optional configuration
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config [nil, Kontena::Registrator::Policy::Config]
  def create(policy, config = nil)
    config_key = config ? config.to_s : nil

    # XXX: rescue initialize errors?
    service = Kontena::Registrator::Service.new_link policy, config, **@service_opts

    logger.info "start #{policy.name} with config=#{config}: #{service}"

    @services[[policy, config_key]] = service
  end

  # Reload configuration for policy
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config [nil, Kontena::Etcd::Model]
  def reload(policy, config = nil)
    service = self[policy, config]

    logger.info "reload #{policy.name} with config=#{config}: #{config.to_json}"

    # XXX: guard against service actor crashes while reloading?
    service.reload config
  end

  # Stop and remove service for a given Policy and configuration path
  #
  # @param policy [Kontena::Registrator::Policy]
  # @param config_path [nil, String]
  def remove(policy, config_path = nil)
    service = @services[[policy, config_path]]

    logger.info "stop #{policy.name} with config=#{config_path}: #{supervisor}"

    # XXX TODO: service.remove
  end

end