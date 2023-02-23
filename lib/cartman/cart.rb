require 'digest/sha1'
require 'json'

module Cartman
  class Cart
    ITEM_DATA_DEFAULT_PROC = -> (hash, key) { hash[key] = Hash.new }

    attr_reader :id, :loaded, :item_data

    def initialize(id)
      @id = id
      @loaded = false
      @item_data = nil
    end

    def add_item(id:, type:, **item_data)
      self.load unless @loaded

      all_item_data =
        { id: id, type: type, **item_data }.transform_keys(&:to_s)

      @item_data[type][id] ||= {}
      @item_data[type][id].merge!(all_item_data) do |key, old_value, new_value|
        case key
        when Cartman.config.quantity_field.to_s then old_value.to_i + new_value.to_i
        else
          new_value
        end
      end
      save

      Item.new(self, @item_data[type][id])
    end

    def remove_item(item)
      self.load unless @loaded

      @item_data[item.type].delete(item.id)
    end

    def items(type=nil)
      self.load unless @loaded

      @item_collection ||=
        ItemCollection.new(
          @item_data.flat_map do |_type, collection|
            collection.values.map { |item| Item.new(self, item) }
          end
        )

      type ? @item_collection.only(type) : @item_collection
    end

    def contains?(object)
      self.load unless @loaded

      @item_data.dig(object.class.to_s, object.id.to_s).present?
    end

    def find(object)
      self.load unless @loaded

      item_data = @item_data.dig(object.class.to_s, object.id.to_s)

      if item_data.present?
        Item.new(self, item_data)
      end
    end

    def count
      self.load unless @loaded

      @item_data.sum { |item_type, items| items.size }
    end

    def quantity
      self.load unless @loaded

      @item_data.sum do |item_type, items|
        items.sum { |id, data| data[Cartman.config.quantity_field.to_s].to_i }
      end
    end

    def total
      self.load unless @loaded

      @item_data.sum { |_item_type, items|
        items.sum { |_id, data| (Item.new(self, data).cost * 100).to_i }
      } / 100.0
    end

    def ttl
      redis.ttl key
    end

    def destroy!
      redis.unlink key
    end

    def touch
      redis.expire key, Cartman.config.cart_expires_in
    end

    def reassign(new_id)
      redis.rename key, key(new_id)
      @id = new_id
    end

    def load
      data = redis.get(key)
      data = data.present? ? JSON.parse(data) : {}
      @item_data = data.fetch("items", {})
      @item_data.default_proc = ITEM_DATA_DEFAULT_PROC
      @loaded = true
    rescue Redis::CommandError => e
      raise unless e.message.match? "WRONGTYPE"
      convert
      retry
    end
    alias_method :reload, :load

    def save
      self.load unless @loaded

      if Cartman.config.cart_expires_in
        redis.setex(key, Cartman.config.cart_expires_in, to_json)
      else
        redis.set(key, to_json)
      end
    end

    def as_json(_options={})
      { id: @id, items: @item_data }
    end

    private

    def key(id=@id)
      "cartman:cart:#{id}"
    end

    CONVERSION_SCRIPT = <<~LUA.freeze
      local line_item_keys = redis.call("smembers", KEYS[1])

      for k, v in pairs(line_item_keys) do
        line_item_keys[k] = "cartman:line_item:"..v
      end

      local new_cart = { id = ARGV[1], items = {} }

      for _, line_item_key in ipairs(line_item_keys) do
        local line_item_data = redis.call("hgetall", line_item_key)
        local line_item = {}

        for i=1, #line_item_data, 2 do
          line_item[line_item_data[i]] = line_item_data[i+1]
        end

        new_cart.items[line_item.type] = new_cart.items[line_item.type] or {}
        new_cart.items[line_item.type][line_item.id] = line_item
      end

      local keys_to_delete = { KEYS[1] }

      for k,v in pairs(redis.call("keys", KEYS[1]..":*")) do
        table.insert(keys_to_delete, v)
      end

      for k,v in pairs(line_item_keys) do
        table.insert(keys_to_delete, v)
      end

      redis.call("del", unpack(keys_to_delete))

      return redis.call("setex", KEYS[1], ARGV[2], cjson.encode(new_cart))
    LUA

    CONVERSION_SCRIPT_SHA = Digest::SHA1.hexdigest(CONVERSION_SCRIPT).freeze

    def convert
      redis.evalsha CONVERSION_SCRIPT_SHA, keys: [key], argv: [id, Cartman.config.cart_expires_in]
    rescue Redis::CommandError
      redis.eval CONVERSION_SCRIPT, keys: [key], argv: [id, Cartman.config.cart_expires_in]
    end

    def redis
      Cartman.config.redis
    end
  end
end
