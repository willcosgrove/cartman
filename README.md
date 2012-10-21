# Cartman

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
Cartman.config do
  cart_expires_in 604800 # one week, in seconds.  This is the default
  return_items_as :openstruct # vs a :hash
  cost_field :cost # for cart totaling
end
```

- The `cart_expires_in` setting will let you set how long a cart should live.  If no items are added to the cart before the time expires, the cart will be cleared.  If you want to disable cart expiration, set this to `-1`.
- `return_items_as` lets you set how you want Cartman to return your items as.  You can choose either an `OpenStruct` or a `Hash`.
- `cost_field` lets you tell Cartman where you're storing the "cost" of each item, so that when you call `cart.total` it knows which values to sum.

## Usage

To create a new shopping cart, just call `Cartman::Cart.new(user.id)`.  The parameter for `Cart.new()` is a unique id.  If you don't want a user to have more than one cart at a time, it's generally best to set this to the user's id.  Then to add an item to the cart, just call `cart.add_item(data)` which takes a hash of data that you want to store.  Then to retrieve the items, you just call `cart.items` which will give you an array of all the items they've added.

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

# app/view/cart/show.html.haml
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
