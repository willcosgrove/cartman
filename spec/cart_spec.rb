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
        expect(cart.send(:key)).to eq("cartman:cart:1")
      end
    end

    describe "#add_item" do
      before(:each) do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, quantity: 2)
      end

      it "creates a line item key" do
        expect(Cartman.config.redis.exists("cartman:line_item:1")).to be true
      end

      it "adds that line item key's id to the cart set" do
        expect(Cartman.config.redis.sismember(cart.send(:key), 1)).to be true
      end

      it "should expire the line_item_keys in the amount of time specified" do
        expect(cart.ttl).to eq(Cartman.config.cart_expires_in)
        expect(Cartman.config.redis.ttl("cartman:line_item:1")).to eq(Cartman.config.cart_expires_in)
      end

      it "should add an index key to be able to look up by type and ID" do
        expect(Cartman.config.redis.exists("cartman:cart:1:index")).to be true
        expect(Cartman.config.redis.sismember("cartman:cart:1:index", "Bottle:17")).to be true
      end

      it "should squack if type and/or ID are not set" do
        expect { cart.add_item(id: 18, name: "Cordeux", unit_cost: 92.12, quantity: 2) }.to raise_error("Must specify both :id and :type")
        expect { cart.add_item(type: "Bottle", name: "Cordeux", unit_cost: 92.12, quantity: 2) }.to raise_error("Must specify both :id and :type")
        expect { cart.add_item(name: "Cordeux", unit_cost: 92.12, quantity: 2) }.to raise_error("Must specify both :id and :type")
      end

      it "should return an Item" do
        item = cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, quantity: 2)
        expect(item.class).to eq(Cartman::Item)
      end
    end

    describe "#remove_item" do
      it "should remove the id from the set, and delete the line_item key" do
        item = cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, quantity: 2)
        item_id = item._id
        cart.remove_item(item)
        expect(Cartman.config.redis.sismember(cart.send(:key), item_id)).to be false
        expect(Cartman.config.redis.exists("cartman:line_item:#{item_id}")).to be false
      end

      it "should not delete the indecies for other items" do
        item = cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, quantity: 2)
        item2 = cart.add_item(id: 18, type: "Bottle", name: "Bordeux", unit_cost: 92.12, quantity: 2)
        expect(Cartman.config.redis.exists("cartman:cart:1:index:Bottle:17")).to be true
        expect(Cartman.config.redis.exists("cartman:cart:1:index:Bottle:18")).to be true
        cart.remove_item(item)
        expect(Cartman.config.redis.exists("cartman:cart:1:index:Bottle:17")).to be false
        expect(Cartman.config.redis.exists("cartman:cart:1:index:Bottle:18")).to be true
      end
    end

    describe "#items" do
      before(:each) do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, quantity: 2)
        cart.add_item(id: 35, type: "GiftCard", name: "Gift Card", unit_cost: 100.00, quantity: 1)
      end

      it "should return an ItemCollection of Items" do
        expect(cart.items.class).to be(Cartman::ItemCollection)
        expect(cart.items.first.class).to be(Cartman::Item)
        expect(cart.items.first.id).to eq("17")
        expect(cart.items.first.name).to eq("Bordeux")
      end

      it "should return all items in cart if no filter is given" do
        expect(cart.items.size).to eq(3)
      end

      it "should return a subset of the items if a filter is given" do
        expect(cart.items("Bottle").size).to eq(2)
        expect(cart.items("GiftCard").size).to eq(1)
        expect(cart.items("SomethingElse").size).to eq(0)
      end
    end

    describe "#contains?(item)" do
      before(:all) do
        Bottle = Struct.new(:id)
      end

      before(:each) do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, quantity: 2)
      end

      it "should be able to tell you that an item in the cart is present" do
        expect(cart.contains?(Bottle.new(17))).to be true
      end

      it "should be able to tell you that an item in the cart is absent" do
        expect(cart.contains?(Bottle.new(20))).to be false
      end

      it "should be able to tell you that an item in the cart is absent if it's been removed" do
        cart.remove_item(cart.items.first)
        expect(cart.contains?(Bottle.new(17))).to be false
        cart.remove_item(cart.items.last)
        expect(cart.contains?(Bottle.new(34))).to be false
      end
    end

    describe "#find(item)" do

      before(:each) do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, quantity: 2)
      end

      it "should take some object, and return the Item that corresponds to it" do
        expect(cart.find(Bottle.new(17)).quantity).to eq("2")
        expect(cart.find(Bottle.new(17)).name).to eq("Bordeux")
        expect(cart.find(Bottle.new(34)).name).to eq("Cabernet")
      end

      it "should return nil if the Item is not in the cart" do
        expect(cart.find(Bottle.new(23))).to be(nil)
      end
    end

    describe "#count" do
      it "should return the number of items in the cart" do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, quantity: 2)
        expect(cart.count).to eq(2)
      end
    end

    describe "#quantity" do
      it "should return the sum of the default quantity field" do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, quantity: 2)
        expect(cart.quantity).to eq(4)
      end

      it "should return the sum of the defined quantity field" do
        Cartman.config do |c|
          c.quantity_field = :qty
        end
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, qty: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, qty: 2)
        expect(cart.quantity).to eq(4)
        Cartman.config do |c|
          c.quantity_field = :quantity
        end
      end
    end

    describe "#total" do
      it "should return 0 when no items are in the cart" do
        expect(cart.total).to eq(0)
      end

      it "should total the default costs field" do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, quantity: 2)
        expect(cart.total).to eq(368.48)
      end

      it "should total whatever cost field the user sets" do
        Cartman.config do |c|
          c.unit_cost_field = :unit_cost_in_cents
        end
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost_in_cents: 9212, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost_in_cents: 9212, quantity: 2)
        expect(cart.total).to eq(36848)
        Cartman.config do |c|
          c.unit_cost_field = :unit_cost
        end
      end
    end

    describe "#destroy" do
      it "should delete the line_item keys, the index key, and the cart key" do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost_in_cents: 18424, quantity: 2)
        cart.add_item(id: 34, type: "Bottle", name: "Cabernet", unit_cost: 92.12, cost_in_cents: 18424, quantity: 2)
        cart.destroy!
        expect(Cartman.config.redis.exists("cartman:cart:1")).to be false
        expect(Cartman.config.redis.exists("cartman:line_item:1")).to be false
        expect(Cartman.config.redis.exists("cartman:line_item:2")).to be false
        expect(Cartman.config.redis.exists("cartman:cart:1:index")).to be false
        expect(Cartman.config.redis.exists("cartman:cart:1:index:Bottle:17")).to be false
      end
    end

    describe "#touch" do
      it "should reset the TTL" do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost_in_cents: 18424, quantity: 2)
        cart.touch
        expect(cart.ttl).to eq(Cartman.config.cart_expires_in)
        expect(Cartman.config.redis.ttl("cartman:cart:1:index")).to eq(Cartman.config.cart_expires_in)
        expect(Cartman.config.redis.ttl("cartman:cart:1:index:Bottle:17")).to eq(Cartman.config.cart_expires_in)
      end

      it "should record that the cart was updated" do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost_in_cents: 18424, quantity: 2)
        cart.touch
        expect(cart.version).to eq(2)
      end
    end

    describe "#reassign" do
      it "should only change the @uid if no key exists" do
        cart.reassign(2)
        expect(cart.send(:key)[-1]).to eq("2")
      end

      it "should rename the key, and index_key if it exists" do
        cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost_in_cents: 18424, quantity: 1)
        cart.add_item(id: 18, type: "Bottle", name: "Merlot", unit_cost: 92.12, cost_in_cents: 18424, quantity: 3)
        expect(cart.quantity).to be(4)
        cart.reassign(2)
        expect(cart.items.size).to be(2)
        expect(Cartman::Cart.new(2).quantity).to be(4)
        expect(Cartman.config.redis.exists("cartman:cart:1")).to be false
        expect(Cartman.config.redis.exists("cartman:cart:1:index")).to be false
        expect(Cartman.config.redis.exists("cartman:cart:1:index:Bottle:17")).to be false
        expect(Cartman.config.redis.exists("cartman:cart:2")).to be true
        expect(Cartman.config.redis.exists("cartman:cart:2:index")).to be true
        expect(Cartman.config.redis.exists("cartman:cart:2:index:Bottle:17")).to be true
        expect(cart.send(:key)[-1]).to eq("2")
        cart.add_item(id: 19, type: "Bottle", name: "Bordeux", unit_cost: 92.12, cost_in_cents: 18424, quantity: 2)
        cart.reassign(1)
        expect(cart.items.size).to be(3)
        expect(Cartman.config.redis.exists("cartman:cart:2")).to be false
        expect(Cartman.config.redis.exists("cartman:cart:2:index")).to be false
        expect(Cartman.config.redis.exists("cartman:cart:1")).to be true
        expect(Cartman.config.redis.exists("cartman:cart:1:index")).to be true
        expect(cart.send(:key)[-1]).to eq("1")
      end
    end

    describe "#cache_key" do
      it "should return /cart/{cart_id}-{version}/" do
        expect(cart.cache_key).to eq("cart/#{cart.instance_variable_get(:@uid)}-#{cart.version}")
      end
    end
  end
end
