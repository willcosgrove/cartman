module Cartman
  class Configuration
    @@configuration = {}
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
          @@configuration.store(method, *args)
        else
          @@configuration.fetch(method)
        end
      end
    end
  end
end
