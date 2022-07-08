require 'delegate'

module Cartman
  class ItemCollection < DelegateClass(Array)
    include Enumerable

    def initialize(array)
      @results = array
      super(@results)
    end

    def each_with_model
      if block_given?
        @results.each do |result|
          yield result, result.model
        end
      else
        enum_for(__method__) { @results.size }
      end
    end
  end
end
