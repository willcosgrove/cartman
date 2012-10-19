module Cartman
  class Cart
    CART_LINE_ITEM_ID_KEY = "cartman:line_item:id"

    def initialize(uid)
      @uid = uid
      @@redis = Cartman::Configuration.redis
    end

    def add_item(options)
      line_item_id = @@redis.incr CART_LINE_ITEM_ID_KEY
      @@redis.mapped_hmset("cartman:line_item:#{line_item_id}", options)
      @@redis.sadd key, line_item_id
    end

    def items
      line_item_ids = @@redis.smembers key
      line_item_ids.collect { |id|
        @@redis.hgetall "cartman:line_item:#{id}"
      }
    end

    private

    def key
      "cartman:cart:#{@uid}"
    end
  end
end
