require 'spec_helper'

describe Cartman do
  describe Cartman::Cart do
    let(:Bottle) { Struct.new(:id) }
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

      it "should add an index key to be able to look up by type and ID" do
        Cartman.config.redis.exists("cartman:cart:1:index").should be_true
        Cartman.config.redis.sismember("cartman:cart:1:index", "Bottle:17").should be_true
      end

      it "should squack if type and/or ID are not set" do
        expect { cart.add_item(id: 18, name: "Cordeux", unit_cost: 92.12, cost: 184.24, quantity: 2) }.to raise_error("Must specify both :id and :type")
        expect { cart.add_item(type: "Bottle", name: "Cordeux", unit_cost: 92.12, cost: 184.24, quantity: 2) }.to raise_error("Must specify both :id and :type")
        expect { cart.add_item(name: "Cordeux", unit_cost: 92.12, cost: 184.24, quantity: 2) }.to raise_error("Must specify both :id and :type")
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

      it "should return an ItemCollection of Items" do
        cart.items.class.should be(Cartman::ItemCollection)
        cart.items.first.class.should be(Cartman::Item)
        cart.items.first.id.should eq("17")
        cart.items.first.name.should eq("Bordeux")
      end
    end

    describe "#contains?(item)" do
      before(:all) do
        Bottle = Struct.new(:id)
      end

      before(:each) do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost: 184.24, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, cost: 184.24, quantity: 2)
      end

      it "should be able to tell you that an item in the cart is present" do
        cart.contains?(Bottle.new(17)).should be_true
      end

      it "should be able to tell you that an item in the cart is absent" do
        cart.contains?(Bottle.new(20)).should be_false
      end

      it "should be able to tell you that an item in the cart is absent if it's been removed" do
        cart.remove_item(cart.items.first)
        cart.contains?(Bottle.new(17)).should be_false
        cart.remove_item(cart.items.last)
        cart.contains?(Bottle.new(34)).should be_false
      end
    end

    describe "#find(item)" do

      before(:each) do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost: 184.24, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, cost: 184.24, quantity: 2)
      end

      it "should take some object, and return the Item that corresponds to it" do
        cart.find(Bottle.new(17)).quantity.should eq("2")
        cart.find(Bottle.new(17)).name.should eq("Bordeux")
        cart.find(Bottle.new(34)).name.should eq("Cabernet")
      end

      it "should return nil if the Item is not in the cart" do
        cart.find(Bottle.new(23)).should be(nil)
      end
    end

    describe "#count" do
      it "should return the number of items in the cart" do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost: 184.24, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, cost: 184.24, quantity: 2)
        cart.count.should eq(2)
      end
    end

    describe "#quantity" do
      it "should return the sum of the default quantity field" do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost: 184.24, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, cost: 184.24, quantity: 2)
        cart.quantity.should eq(4)
      end

      it "should return the sum of the defined quantity field" do
        Cartman.config do
          quantity_field :qty
        end
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost: 184.24, qty: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, cost: 184.24, qty: 2)
        cart.quantity.should eq(4)
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

    describe "#destroy" do
      it "should delete the line_item keys, the index key, and the cart key" do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost_in_cents: 18424, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, cost_in_cents: 18424, quantity: 2)
        cart.destroy!
        Cartman.config.redis.exists("cartman:cart:1").should be_false
        Cartman.config.redis.exists("cartman:line_item:1").should be_false
        Cartman.config.redis.exists("cartman:line_item:2").should be_false
        Cartman.config.redis.exists("cartman:cart:1:index").should be_false
        Cartman.config.redis.exists("cartman:cart:1:index:Bottle:17").should be_false
      end
    end

    describe "#touch" do
      it "should reset the TTL" do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost_in_cents: 18424, quantity: 2)
        cart.touch
        cart.ttl.should eq(Cartman.config.cart_expires_in)
        Cartman.config.redis.ttl("cartman:cart:1:index").should eq(Cartman.config.cart_expires_in)
        Cartman.config.redis.ttl("cartman:cart:1:index:Bottle:17").should eq(Cartman.config.cart_expires_in)
      end
    end

    describe "#reassign" do
      it "should only change the @uid if no key exists" do
        cart.reassign(2)
        cart.send(:key)[-1].should eq("2")
      end

      it "should rename the key, and index_key if it exists" do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost_in_cents: 18424, quantity: 2)
        cart.reassign(2)
        Cartman.config.redis.exists("cartman:cart:1").should be_false
        Cartman.config.redis.exists("cartman:cart:1:index").should be_false
        Cartman.config.redis.exists("cartman:cart:1:index:Bottle:17").should be_false
        Cartman.config.redis.exists("cartman:cart:2").should be_true
        Cartman.config.redis.exists("cartman:cart:2:index").should be_true
        Cartman.config.redis.exists("cartman:cart:2:index:Bottle:17").should be_true
        cart.send(:key)[-1].should eq("2")
        cart.add_item(id: 18, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost_in_cents: 18424, quantity: 2)
        cart.reassign(1)
        Cartman.config.redis.exists("cartman:cart:2").should be_false
        Cartman.config.redis.exists("cartman:cart:2:index").should be_false
        Cartman.config.redis.exists("cartman:cart:1").should be_true
        Cartman.config.redis.exists("cartman:cart:1:index").should be_true
        cart.send(:key)[-1].should eq("1")
      end
    end
  end
end
