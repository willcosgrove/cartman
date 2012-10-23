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
      keys_to_expire = line_item_keys
      keys_to_expire << key
      @@redis.pipelined do
        keys_to_expire.each do |item|
          @@redis.expire item, Cartman::Configuration.cart_expires_in
        end
      end
      get_item(line_item_id)
    end

    def remove_item(item)
      @@redis.del "cartman:line_item:#{item._id}"
      @@redis.srem key, item._id
    end

    def items
      items = line_item_ids.collect { |item_id|
        get_item(item_id)
      }
    end

    def total
      items.collect { |item|
        (item.send(Cartman::Configuration.cost_field).to_f * 100).to_i
      }.inject{|sum,cost| sum += cost} / 100.0
    end

    def ttl
      @@redis.ttl key
    end

    private

    def key
      "cartman:cart:#{@uid}"
    end

    def line_item_ids
      @@redis.smembers key
    end

    def line_item_keys
      line_item_ids.collect{ |id| "cartman:line_item:#{id}" }
    end

    def get_item(id)
      Item.new(id, @uid, @@redis.hgetall("cartman:line_item:#{id}").inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo})
    end
  end
end
