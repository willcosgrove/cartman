require 'spec_helper'

describe Cartman do
  describe Cartman::Cart do
    let(:cart) { Cartman::Cart.new(1) }

    before(:all) do
      Cartman.config do
        redis Redis.new
      end
    end

    before(:each) do
      Cartman.config.redis.flushdb
    end

    describe "#key" do
      it "should return a proper key string" do
        cart.send(:key).should eq("cartman:cart:1")
      end
    end

    describe "#add_item" do
      before(:each) do
        cart.add_item(id: 17, class: "Bottle", name: "Bordeux", unit_cost: 92.12, cost: 184.24, quantity: 2)
      end

      it "creates a line item key" do
        Cartman.config.redis.exists("cartman:line_item:1").should be_true
      end
      it "adds that line item key's id to the cart set" do
        Cartman.config.redis.sismember(cart.send(:key), 1).should be_true
      end
    end

    describe "#items" do
      before(:each) do
        cart.add_item(id: 17, class: "Bottle", name: "Bordeux", unit_cost: 92.12, cost: 184.24, quantity: 2)
        cart.add_item(id: 34, class: "Bottle", name: "Cabernet", unit_cost: 92.12, cost: 184.24, quantity: 2)
      end

      it "should return an array of hashes" do
        cart.items.class.should eq(Array)
        cart.items.first.class.should eq(Hash)
        cart.items.size.should eq(2)
      end
    end
  end
end
