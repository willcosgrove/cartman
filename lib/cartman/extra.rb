module Cartman
  class Extra
    def initialize(cart_id)
      @cart_id = cart_id
    end

    def cart
      @cart ||= Cart.new(@cart_id)
    end

    def cart_key
      @cart_key ||= cart.send(:key)
    end

    def [](name)
      raise ArgumentError, "extra[] key name must be a String" unless name.is_a?(String)

      key = extra_key(name)

      case key_type = redis.type(key).to_sym
      when :string then
        redis.get(key)
      when :set then
        redis.smembers(key)
      when :hash then
        redis.hgetall(key).inject({}) { |hash, (k, v)| hash[k.to_sym] = v; hash }
      when :none then
        nil
      else
        raise ArgumentError, "#{key_type} is not supported"
      end
    end

    def []=(name, value)
      raise ArgumentError, "extra[] key name must be a String" unless name.is_a?(String)

      key = extra_key(name)
      redis.del(key) if redis.exists?(key)
      case value
      when Hash then
        redis.mapped_hmset(key, value)
      when Array then
        redis.sadd(key, value)
      else
        redis.set(key, value) unless value.nil?
      end
      cart.touch
      value
    end

    def extra_key(name)
      "#{cart_key}:extra:#{name}"
    end

    private

    def redis
      Cartman.config.redis
    end

  end
end
