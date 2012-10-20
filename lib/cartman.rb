require "cartman/version"
require "cartman/configuration"
require "cartman/cart"
require 'redis'
require 'ostruct'

module Cartman
  module_function
  def config(&block)
    if block_given?
      @config = Configuration.new(&block)
    else
      @config
    end
  end
end
