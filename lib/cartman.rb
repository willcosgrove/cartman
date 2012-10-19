require "cartman/version"
require "cartman/configuration"

module Cartman
  def config(&block)
    Configuration.new(&block)
  end
end
