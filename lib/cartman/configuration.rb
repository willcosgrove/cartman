module Cartman
  class Configuration
    @@configuration = {
      cart_expires_in: 604800, # one week
      return_items_as: :openstruct, # vs a :hash
      cost_field: :cost, # for cart totaling
    }

    def initialize(&block)
      instance_eval &block
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
