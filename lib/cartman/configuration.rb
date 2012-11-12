require "redis"

module Cartman
  class Configuration
    attr_accessor :cart_expires_in, :unit_cost_field, :quantity_field
    attr_writer :redis

    def initialize
      @cart_expires_in = 604800
      @unit_cost_field = :unit_cost
      @quantity_field = :quantity
    end

    def redis
      @redis ||= Redis.new
    end
  end
end
