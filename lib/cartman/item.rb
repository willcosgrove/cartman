module Cartman
  class Item
    def initialize(item_id, cart_id, data)
      @id = item_id
      @cart_id = cart_id
      @data = data
    end

    def _id
      @id
    end

    def cost
      unit_cost = (@data.fetch(Cartman::Configuration.unit_cost_field).to_f * 100).to_i
      quantity = @data.fetch(Cartman::Configuration.quantity_field).to_i
      (unit_cost * quantity) / 100.0
    end

    def cart
      @cart ||= Cart.new(@cart_id)
    end

    def destroy
      cart.remove_item(self)
    end

    def ==(item)
      @id == item._id
    end

    def _key
      "cartman:line_item:#{@id}"
    end

    def method_missing(method, *args, &block)
      if method.to_s =~ /=\z/
        Cartman::Configuration.redis.hset _key, method[0..-2], args[0].to_s
        @data.store(method[0..-2].to_sym, args[0].to_s)
      else
        @data.fetch(method)
      end
    end
  end
end
