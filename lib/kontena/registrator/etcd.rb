require 'kontena/logging'
require 'kontena/etcd/client'
require 'etcd/keys_helpers'

module Kontena::Registrator::Etcd

  # Maintain a set of nodes in etcd.
  #
  # Call update with the full set of nodes each time to create/set/delete etcd
  # nodes as needed.
  #
  # Nodes can be written with a TTL, which ensures that stale nodes are cleaned up
  # if the writer crashes. Using a TTL requires periodically calling refresh to
  # maintain the nodes in etcd.
  class Writer
    include Kontena::Logging

    def initialize(ttl: nil)
      @nodes = { }
      @client = Kontena::Etcd::Client.new
      @ttl = ttl

      logger.info "Connected to etcd=#{@client.uri} with version=#{@client.version}"
    end

    def ttl
      @ttl
    end

    # Update set of path => value nodes to etcd
    def update(nodes)
      nodes.each_pair do |key, value|
        if value != @nodes[key]
          @client.set(key, value: value, ttl: @ttl)
        end
      end

      @nodes.each do |key, value|
        if !nodes[key]
          @client.delete(key)
        end
      end

      @nodes = nodes
    end

    # Refresh currently active etcd nodes when using a TTL
    def refresh
      raise ArgumentError, "Refresh without TTL" unless @ttl
      
      logger.debug "refresh #nodes=#{@nodes.size} with ttl=#{@ttl}"

      @nodes.each do |key, value|
        @client.refresh(key, @ttl)
      end
    end
  end
end
