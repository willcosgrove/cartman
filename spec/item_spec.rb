require 'spec_helper'

describe Cartman do
  describe Cartman::Item do
    let(:cart) { Cartman::Cart.new(1) }
    let(:item) { cart.add_item(id: 17, type: "Bottle", name: "Bordeux", unit_cost: 92.12, quantity: 2) }

    describe "data getters and setters" do
      it "should let me get data stored for the item" do
        expect(item.id).to eq("17")
        expect(item.type).to eq("Bottle")
        expect(item.cost).to eq(184.24)
      end

      it "should let me modify data stored for the item" do
        expect(item.quantity).to eq("2")
        item.quantity = 3
        expect(item.quantity).to eq("3")
      end

      it "should immediately save data back to redis" do
        expect(item.quantity).to eq("2")
        item.quantity = 3
        new_item = cart.send(:get_item, item._id)
        expect(new_item.quantity).to eq("3")
      end

      it "should touch the item and cart" do
        expect{item.quantity = 4}.to change{item._version}.by(1)
      end

      it "should raise NoMethodError if you use a getter that there isn't a key for" do
        expect{ item.weight }.to raise_error(NoMethodError)
      end

      it "should respond_to the getters and setters" do
        expect(item.respond_to?(:name)).to be true
        expect(item.respond_to?(:name=)).to be true
      end
    end

    describe "#cost" do
      it "should be equal to the unit_cost multiplied by the quantity" do
        expect(item.cost).to eq(184.24)
        item.quantity = 3
        expect(item.cost).to eq(276.36)
      end
    end

    describe "#destroy" do
      it "should remove the item from the cart" do
        item_id = item._id
        item.destroy
        expect(Cartman.config.redis.sismember(cart.send(:key), item_id)).to be false
        expect(Cartman.config.redis.exists("cartman:line_item:#{item_id}")).to be false
      end
    end

    describe "#touch" do
      it "should record that the record was changed" do
        item.touch
        expect(item._version).to eq(1)
      end
    end

    describe "#cache_key" do
      it "should return item/{id}-{version}" do
        expect(item.cache_key).to eq("item/#{item._id}-#{item._version}")
      end
    end

  end
end
