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
      if options.has_key?(:id) && options.has_key?(:type)
        @@redis.sadd index_key, "#{options[:type]}:#{options[:id]}"
      end
      touch
      get_item(line_item_id)
    end

    def remove_item(item)
      @@redis.del "cartman:line_item:#{item._id}"
      @@redis.srem key, item._id
      begin
        @@redis.srem index_key, item.instance_of?(Item) ? "#{item.type}:#{item.id}" : "#{item.class}:#{item.id}"
      rescue KeyError
      end
      touch
    end

    def get_item(id)
      Item.new(id, @uid, @@redis.hgetall("cartman:line_item:#{id}").inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo})
    end

    def items
      items = line_item_ids.collect { |item_id|
        get_item(item_id)
      }
    end

    def contains?(object)
      @@redis.sismember index_key, "#{object.class}:#{object.id}"
    end

    def count
      @@redis.scard key
    end

    def quantity
      line_item_keys.collect { |item_key|
        @@redis.hget item_key, Cartman::Configuration.quantity_field
      }.inject(0){|sum,quantity| sum += quantity.to_i}
    end

    def total
      items.collect { |item|
        (item.send(Cartman::Configuration.cost_field).to_f * 100).to_i
      }.inject{|sum,cost| sum += cost} / 100.0
    end

    def ttl
      @@redis.ttl key
    end

    def destroy!
      keys = line_item_keys
      keys << key
      keys << index_key
      @@redis.pipelined do
        keys.each do |key|
          @@redis.del key
        end
      end
    end

    def touch
      keys_to_expire = line_item_keys
      keys_to_expire << key
      keys_to_expire << index_key
      @@redis.pipelined do
        keys_to_expire.each do |item|
          @@redis.expire item, Cartman::Configuration.cart_expires_in
        end
      end
    end

    def reassign(new_id)
      if @@redis.exists key
        @@redis.rename key, key(new_id)
      end
      if @@redis.exists index_key
        @@redis.rename index_key, index_key(new_id)
      end
      @uid = new_id
    end

    private

    def key(id=@uid)
      "cartman:cart:#{id}"
    end

    def index_key(id=@uid)
      key(id) + ":index"
    end

    def line_item_ids
      @@redis.smembers key
    end

    def line_item_keys
      line_item_ids.collect{ |id| "cartman:line_item:#{id}" }
    end

  end
end
