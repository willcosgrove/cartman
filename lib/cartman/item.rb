require 'digest/sha1'

module Cartman
  class Item
    extend Forwardable

    attr_reader :cart

    UNSET = Object.new
    def initialize(cart, data)
      @cart = cart
      @data = data
      @model = UNSET
    end

    def_delegator :cart, :save

    def cost
      unit_cost = (@data[Cartman.config.unit_cost_field.to_s].to_f * 100).to_i
      quantity = @data[Cartman.config.quantity_field.to_s].to_i
      (unit_cost * quantity) / 100.0
    end

    def destroy
      cart.remove_item(self)
      cart.save
      @cart = nil
    end

    def destroyed?
      @cart.nil?
    end

    def key
      Digest::SHA1.hexdigest("#{type}/#{id}")
    end
    alias_method :_id, :key

    def to_param
      key
    end

    def id
      @data.fetch("id")
    end

    def type
      @data.fetch("type")
    end

    def model
      return @model if model_set?

      @model = Object.const_get(type).find(id)
    end

    def set_model(model)
      @model = model
    end

    def model_set?
      @model != UNSET
    end

    def as_json(_options={})
      @data.as_json
    end

    def method_missing(method, *args, &block)
      field = method.to_s
      assignment = false

      if field.ends_with? "="
        assignment = true
        field = field[0...-1]
      end

      if @data.has_key? field
        if assignment
          @data[field] = args.first
        else
          @data[field]
        end
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      method = method.to_s
      method = method[0...-1] if method.ends_with?("=")

      @data.has_key?(method) || super
    end
  end
end
