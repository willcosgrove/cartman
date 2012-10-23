require 'redis'

module Cartman
  class Configuration
    @@configuration = {
      cart_expires_in: 604800, # one week
      cost_field: :cost, # for cart totaling
      redis: Redis.new, # Redis connection
    }

    def initialize(&block)
      instance_eval &block if block_given?
    end

    def method_missing(method, *args, &block)
      if !args.empty?
        @@configuration.store(method, *args)
      else
        @@configuration.fetch(method)
      end
    end
    
    class << self
      def method_missing(method, *args, &block)
        if !args.empty?
          @@configuration.store(method, args[0])
        else
          @@configuration.fetch(method)
        end
      end
    end
  end
end
