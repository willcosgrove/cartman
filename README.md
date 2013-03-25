# Cartman
[![Build Status](https://secure.travis-ci.org/willcosgrove/cartman.png)](http://travis-ci.org/willcosgrove/cartman)

![](http://blog.brightcove.com/sites/all/uploads/eric_theodore_cartman_southpark.jpg)

Cartman is a framework agnostic, redis backed, cart system.  It is not a POS, or a full fledged ecommerce system.  Just the cart, man.

## Installation

Add this line to your application's Gemfile:

    gem 'cartman'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cartman

## Setup

Cartman has a few (read 3) configuration options you can set, most likely in an initializer file.  Here's an example configuration:

```ruby
# config/initializers/cartman.rb
Cartman.config do |c|
  c.cart_expires_in = 604800 # one week, in seconds.  This is the default
  c.unit_cost_field = :unit_cost # for cart totaling
  c.quantity_field = :quantity # for quantity totaling
  c.redis = Redis.new # set the redis connection here
end
```

- The `cart_expires_in=` setting will let you set how long a cart should live.  If no items are added to the cart before the time expires, the cart will be cleared.  If you want to disable cart expiration, set this to `-1`.
- `unit_cost_field=` lets you tell Cartman where you're storing the unit_cost of each item, so that you can use the `cost` method on the item, and the `total` method on `Cart`.
- `quantity_field=` lets you tell Cartman where you're storing the quantity of each item.  The `Item#cost` method uses this along with the `unit_cost` field to determine the cost.
- `redis=` lets you set the redis connection you want to use.  Note that this is not redis connection options, this is an actual instance of `Redis`.

## Usage

To create a new shopping cart, just call `Cartman::Cart.new(user.id)`.  The parameter for `Cart.new()` is a unique id.  If you don't want a user to have more than one cart at a time, it's generally best to set this to the user's id.  Then to add an item to the cart, just call `cart.add_item(data)` which takes a hash of data that you want to store.  Then to retrieve the items, you just call `cart.items` which will give you an array of all the items they've added.

The returned Items come back as `Cartman::Item` instances, which have a few special methods to be aware of:

- `cost` - which will return the `:unit_cost` multiplied by the `:quantity`.
- `destroy` - which will remove the item from the cart
- `cart` - which will return the parent cart, think ActiveRecord association
- `_id` - which will return the id of the item, if you need that for whatever reason
- `_key` - which will return the redis key the data is stored in.  Probably won't need that, but it's there.
- `#{attribute}=` - this is a setter defined for all of the items attributes that you gave it.  It will instantly save to redis also, so no need to call `save` (which is why there isn't a `save`).

The `Cart` object also has some handy methods that you should be aware of:

- `add_item(data)` - which is the life blood of Cartman.  This method takes a hash of data you would like to store with the item.  Here's a few suggestions of keys you may want in your hash:
  - `:id` - (*required*) to store the ID of the model you're adding
  - `:type` - (*required*) to store the class of the model you're adding.
  - `:unit_cost` - This field is required if you want to take advantage of the `Item#cost` method, and the `Cart#total` method.
  - `:quantity` - which if you use will let you use the `Cart#quantity` and `Cart#total` methods without any extra configuration.
- `remove_item(item)` - which, you guessed it, removes an item.  This method takes an Item object, not a hash.
- `contains?(Product)` - This is a biggie.  It will tell you if a certain item is in the cart.  And the way it works is you pass it an object, like an instance of a Product model, and it will examine the class, and the id, and look to see if it's in the cart already.  This method only works if the `:id` and `:type` keys are set in the item's data hash.
- `find(Product)` - This will return the `Item` object that represents the object passed in.  It works like `contains?` and uses class, and id.  It only works if the `:id` and `:type` keys are set in the item's data hash.
- `items` - this returns a magic array of all the items.  You can also pass in a type string, which will return a magic array of all the items with a matching type.  I call it magic because you can call on it:
  - `each_with_object` - which will act like a regular `each` call, but the block will yield the `Item` and the object it represents by using the `:type` and `:id` keys.
- `total` - will sum all of the `cost` return values of all of the items in the cart.  For this to work, the `:unit_cost` and `:quantity` fields need to be set for all items.
- `count` - which will give you the total number of items in the cart.  Faster than `cart.items.size` because it doesn't load all of the item data from redis.
- `quantity` - which will return the total quantity of all the items.  The quantity field is set in the config block, by default it's `:quantity`
- `ttl` - will tell you how many seconds until the cart expires.  It will return -1 if the cart will never expire.
- `touch` - which will reset the ttl back to whatever expiration length is set in the config.  Touch is automatically called after `add_item` and `remove_item`.
- `destroy!` - which will delete the cart, and all the line_items out of it.
- `reassign(id)` - this method will reassign the cart's unique identifier.  So to access this cart at a later time after reassigning, you would put `Cart.new(reassigned_id)`.  This is useful for having a cart for an unsigned in user.  You can use their session ID while they're unauthenticated, and then when they sign in, you can reassign the cart to the user's ID.  NOTE: Reassigning will overwrite any cart in it's way.

Lets walk through an example implementation with a Rails app that has a User model and a Product model.

```ruby
# app/models/user.rb
class User < ActiveRecord::Base
  #...
  def cart
    Cartman::Cart.new(id)
  end
  #...
end
```

```ruby
# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  #...
  # /products/:id/add_to_cart
  def add_to_cart
    @product = Product.find(params[:id])
    current_user.cart.add_item(id: @product.id, name: @product.name, unit_cost: @product.cost, cost: @product.cost * params[:quantity], quantity: params[:quantity])
  end
  #...
end
```

```haml
-# app/view/cart/show.html.haml
%h1 Cart - Total: #{@cart.total}
%ul
  - @cart.items.each do |item|
    %li #{item.name} - #{item.cost}
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
