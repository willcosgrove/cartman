require 'spec_helper'

describe Cartman do
  describe Cartman::Cart do
    let(:cart) { Cartman::Cart.new(1) }

    before(:each) do
      Cartman.config.redis.flushdb
    end

    describe "extra_key" do
      it "should be type of Cart::Extra" do
        expect(cart.extra).to be_a(Cartman::Extra)
      end

      it "should store a Boolean as a String" do
        cart.extra['self_picking'] = true
        expect(cart.extra['self_picking']).to eq('true')
      end

      it "should store a number as a String" do
        cart.extra['discount'] = 10
        expect(cart.extra['discount']).to eq('10')

        # Make sure key really exists in Redis
        expect(Cartman.config.redis.exists("cartman:cart:1:extra:discount")).to be true
        expect(Cartman.config.redis.get("cartman:cart:1:extra:discount")).to eq('10')
      end

      it "should store a String" do
        cart.extra['code'] = 'XB22'
        expect(cart.extra['code']).to eq('XB22')
      end

      it "should store a BigDecimal" do
        cart.extra['discount'] = BigDecimal(1.25, 2)
        expect(BigDecimal(cart.extra['discount'])).to eq(BigDecimal(1.25, 2))
      end

      it "should store an Array as a set of Strings" do
        cart.extra['test'] = [ 1, 2, 3 ]
        test = cart.extra['test']
        expect(test).to be_an_instance_of(Array)
        expect(test.length).to be(3)
        expect(test).to match_array([1, 2, 3].map(&:to_s))
      end

      it "should store a Hash as a map of Strings Values" do
        cart.extra['test'] = { a: 1, b: 2 }
        test = cart.extra['test']
        expect(test).to be_an_instance_of(Hash)
        expect(test).to eq({a: '1', b: '2'})
      end

      it "should overwrite previous values" do
        cart.extra['self_picking'] = false
        cart.extra['self_picking'] = true
        expect(cart.extra['self_picking']).to eq('true')
      end

      it "should remove extra keys when assigned nil" do
        cart.extra['discount'] = 10
        cart.extra['discount'] = nil
        expect(Cartman.config.redis.exists("cartman:cart:1:extra:discount")).to be false
      end

      it "should raise an error if extra[] key is anything but a String" do
        expect { cart.extra[2] }.to raise_error(ArgumentError)
        expect { cart.extra[2] = 'test' }.to raise_error(ArgumentError)
      end
    end

    describe "#destroy" do
      it "should delete the extra keys" do
        cart.extra['self_picking'] = true
        cart.destroy!
        expect(Cartman.config.redis.exists("cartman:cart:1")).to be false
        expect(Cartman.config.redis.exists("cartman:cart:1:extra:self_picking")).to be false
      end
    end

    describe "#touch" do
      it "should reset the TTL" do
        cart.extra['self_picking'] = true
        cart.touch
        expect(Cartman.config.redis.ttl("cartman:cart:1:extra:self_picking")).to eq(Cartman.config.cart_expires_in)
      end

      it "should record that the cart was updated" do
        cart.extra['self_picking'] = true
        cart.touch
        expect(cart.version).to eq(2)
      end
    end

    describe "#reassign" do
      it "should rename the extra_keys if they exists" do
        cart.extra['self_picking'] = true
        cart.extra['discount'] = { applied: true, code: 'Z42XB12' }

        cart.reassign(2)
        expect(Cartman.config.redis.exists("cartman:cart:1:extra:self_picking")).to be false
        expect(Cartman.config.redis.exists("cartman:cart:1:extra:discount")).to be false
        expect(Cartman.config.redis.exists("cartman:cart:2:extra:self_picking")).to be true
        expect(Cartman.config.redis.exists("cartman:cart:2:extra:discount")).to be true

        cart.reassign(1)
        expect(Cartman.config.redis.exists("cartman:cart:1:extra:self_picking")).to be true
        expect(Cartman.config.redis.exists("cartman:cart:1:extra:discount")).to be true
        expect(Cartman.config.redis.exists("cartman:cart:2:extra:self_picking")).to be false
        expect(Cartman.config.redis.exists("cartman:cart:2:extra:discount")).to be false
      end
    end
  end
end
