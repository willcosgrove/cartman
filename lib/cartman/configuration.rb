module Cartman
  class Configuration
    @@configuration = {}
    def initialize(&block)
      instance_eval &block
    end
    
    def method_missing(method, *args, &block)
      if method.to_s ~= /=/
        @@configuration.store(method, *args)
      else
        @@configuration.fetch(method)
      end
    end
  end
end
