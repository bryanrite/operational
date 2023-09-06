# Operational

Applications usually start out simple, actions are largely CRUD-y and isolated to a single database backed model. As they grow and complicated business logic creeps in, something to orchestrate the action helps to keep concerns separated and decouple business logic from data persistence.

This is what **Operational** attempts to solve.

Operational introduces a number of concepts to solve these problems while relying on Ruby on Rails' ActiveModel to keep the code **small** and **dependency free**. This enables powerful organization of code, high readability, and a DSL like collection of business actions with a very light touch.

This gem is heavily inspired by [Trailblazer](https://github.com/trailblazer/trailblazer) and [dry-rb](https://dry-rb.org/), both of which I have used extensively for many years. Operational solves a similar but much small subset of problems and relies on ActiveModel conventions, rather than being framework agnostic; meaning there is far less code, moving parts, and no dependencies.

Read more about Operational's motivations here: [https://bryanrite.com/simplifying-complex-rails-apps-with-operations/](https://bryanrite.com/simplifying-complex-rails-apps-with-operations/)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'operational'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install operational


## Getting Started

See the [Operational Wiki](https://github.com/bryanrite/operational/wiki) for an explanation of the concepts introduced by Operational and show how to start using them in your own applications.


## RDocs

To come.


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bryanrite/operational. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

