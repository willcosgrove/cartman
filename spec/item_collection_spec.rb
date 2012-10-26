require 'spec_helper'

describe Cartman do
  describe Cartman::ItemCollection do
    before(:all) do
    end

    before(:each) do
      Cartman.config.redis.flushdb
      Object.send(:remove_const, :Bottle) if defined?(Bottle)
      Bottle = double
      Bottle.stub(:find).and_return(bottle)
    end
    
    describe "#each_with_object" do
      let(:bottle) { double("Bottle") }
      it "should be magical" do
        cart = Cartman::Cart.new(1)
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost: 184.24, quantity: 2) 
        expect { |b| cart.items.each_with_object(&b)}.to yield_successive_args([cart.items.first, bottle])
      end
    end
  end
end
