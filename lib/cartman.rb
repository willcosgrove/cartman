require "cartman/version"
require "cartman/configuration"
require "cartman/cart"
require "cartman/item"
require 'redis'
require 'ostruct'

module Cartman
  module_function
  def config(&block)
    if block_given?
      @config = Configuration.new(&block)
    else
      @config ||= Configuration.new
    end
  end
end
