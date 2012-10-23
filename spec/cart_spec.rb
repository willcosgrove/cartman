require 'spec_helper'

describe Cartman do
  describe Cartman::Cart do
    let(:cart) { Cartman::Cart.new(1) }

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
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost: 184.24, quantity: 2)
      end

      it "creates a line item key" do
        Cartman.config.redis.exists("cartman:line_item:1").should be_true
      end

      it "adds that line item key's id to the cart set" do
        Cartman.config.redis.sismember(cart.send(:key), 1).should be_true
      end

      it "should expire the line_item_keys in the amount of time specified" do
        cart.ttl.should eq(Cartman.config.cart_expires_in)
        Cartman.config.redis.ttl("cartman:line_item:1").should eq(Cartman.config.cart_expires_in)
      end

      it "should return an Item" do
        item = cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, cost: 184.24, quantity: 2)
        item.class.should eq(Cartman::Item)
      end
    end

    describe "#remove_item" do
      it "should remove the id from the set, and delete the line_item key" do
        item = cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost: 184.24, quantity: 2)
        item_id = item._id
        cart.remove_item(item)
        Cartman.config.redis.sismember(cart.send(:key), item_id).should be_false
        Cartman.config.redis.exists("cartman:line_item:#{item_id}").should be_false
      end
    end

    describe "#items" do
      before(:each) do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost: 184.24, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, cost: 184.24, quantity: 2)
      end

      it "should return an array of Items" do
        cart.items.first.class.should eq(Cartman::Item)
        cart.items.first.id.should eq("17")
        cart.items.first.name.should eq("Bordeux")
      end
    end

    describe "#total" do
      it "should total the default costs field" do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost: 184.24, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, cost: 184.24, quantity: 2)
        cart.total.should eq(368.48)
      end

      it "should total whatever cost field the user sets" do
        Cartman.config do
          cost_field :cost_in_cents
        end
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost_in_cents: 18424, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, cost_in_cents: 18424, quantity: 2)
        cart.total.should eq(36848)
      end
    end
  end
end
