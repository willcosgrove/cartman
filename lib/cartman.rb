require "cartman/version"
require "cartman/configuration"

module Cartman
  module_function
  def config(&block)
    Configuration.new(&block)
  end
end
