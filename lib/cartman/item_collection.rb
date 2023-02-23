require 'delegate'

module Cartman
  class ItemCollection < DelegateClass(Array)
    include Enumerable

    def initialize(array)
      @results = array
      super(@results)
    end

    def each_with_model(includes: [])
      if block_given?
        model_cache = Hash.new { |h, key| h[key] = {} }
        id_collection = Hash.new { |h, key| h[key] = [] }

        @results.each do |item|
          next if item.model_set?
          id_collection[item.type] << item.id
        end

        id_collection.each do |model_class_name, ids|
          model_cache[model_class_name] = Object.const_get(model_class_name).includes(includes).find(ids).index_by(&:id)
        end

        @results.each do |result|
          model = model_cache[result.type][result.id]
          result.set_model(model) if model
          yield result, result.model
        end
      else
        enum_for(__method__, includes: includes) { @results.size }
      end
    end

    def only(*types)   = self.class.new(select { types.include?(_1.type) })
    def except(*types) = self.class.new(reject { types.include?(_1.type) })
  end
end
