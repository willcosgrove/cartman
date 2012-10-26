require 'delegate'

module Cartman
  class ItemCollection < DelegateClass(Array)
    include Enumerable

    def initialize(array)
      @results = array
      super(@results)
    end

    def each_with_object
      @results.each do |result|
        yield result, eval(result.type).send(:find, result.id)
      end
    end

  end
end
