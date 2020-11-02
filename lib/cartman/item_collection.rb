require 'delegate'

module Cartman
  class ItemCollection < DelegateClass(Array)
    include Enumerable

    def initialize(array)
      @results = array
      super(@results)
    end

    def each_with_model
      @results.each do |result|
        yield result, result.model
      end
    end
  end
end
