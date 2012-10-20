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
    end

    def items(return_as=Cartman::Configuration.return_items_as)
      items = line_item_keys.collect { |item_key|
        @@redis.hgetall(item_key).inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo} # symbolize keys
      }
      if return_as == :openstruct
        items.collect { |item|
          OpenStruct.new(item)
        }
      else
        items
      end
    end

    def total
      items(:openstruct).collect { |item|
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
  end
end
