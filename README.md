# Operational

Applications usually start out simple, actions are largely CRUD-y and isolated to a single database backed model. As they grow and complicated business logic creeps in, something to orchestrate the action helps to keep concerns separated and decouple business logic from data persistence.

This is what **Operational** attempts to solve.

Operational introduces the concepts of functional _Operations_ and _Form Objects_, to solve these problems, relying on Ruby on Rails' ActiveModel to keep the code **small** and **dependency free**. This enables very powerful organization of code with a light touch.

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


## Guide

The main concepts introduced by Operational are:

**Operations** are an orchestrator, or wrapper, around a business process. They don't _do_ a lot themselves but provide an interface for executing all the business logic in an action while keeping the data persistence and service objects isolated and decoupled.

**Railway Oriented/Monad Programming** is a functional way to define the business logic steps in an action, simplifying the handling of happy paths and failure paths in easy to understand tracks. You define steps that execute in order, the result of the step (truthy or falsey) moves execution to the success or failure tracks. Reduce complicated conditionals with explict methods.

**Functional State** is the idea that each step in an operation receives parameters from the previous step, much like Unix pipe passing output from one command to the next. This state is a single hash that allows you to encapsulate all the information an operation might need, like `current_user`, `params`, or `remote_ip` and provide it in a single point of access. It is mutable within the execution of the operation, so steps may add to it, but immutable at the end of the operation.

**Form Objects** help decouple data persistence from your view. They allow you to define a form or API that may touch many different ActiveRecord models without needing to couple those models together. Validation can be done in the form, where it is more contextually appropriate, rather than on the model. Form Objects more securely define what attributes a request may submit without the need for `StrongParameters`, as they are not directly database backed and do not suffer from mass assignment issues StrongParameters tries to solve.


## Getting Started

Bringing the above concepts to bear, a typical Rails action using Operational may look like:

```ruby
# app/controllers/todos_controller.rb
class TodosController < ActionController::Base
  include Operational::Controller

  # By default, params and current_user are set to the state for each operation, this can
  # be overridden at the controller level.

  def new
    # Run the Present part of the operation, which typically sets up the model and form.
    run Todos::CreateOperation::Present
  end

  def create
    # Run the entire operation, the result of the operation decides what to do, rather
    # than, as in typical Rails fashion, whether the model saved or not.
    if run Todos::CreateOperation
      return redirect_to todo_path(@state[:todo].id), notice: "Created Successfully."
    else
      render :new
    end
  end
end

# app/concepts/todos/create_form.rb
module Todos
  class CreateForm < Operational::Form
    # Define attributes and type that this form will accept. Replaces the implicitly
    # defined ActiveRecord attributes with an explicit list not coupled to any model.
    # Strong Parameters is no longer required.
    attribute :description, :string

    # Define active model validations as normal.
    validates :description, presence: true, length: { maximum: 500 }
  end
end

# app/concepts/todos/create_operation.rb
module Todos
  class CreateOperation < Operational::Operation

    # Create a model(s), build a form object.
    class Present < Operational::Operation
      step :setup_new_model
      step Contract::Build(contract: CreateForm, model_key: :todo)

      def setup_model(state)
        state[:todo] = Todo.new(user: state[:current_user])
      end
    end

    # Run the Present part.
    step Nested::Operation(operation: Present)
    # Validiate the form, if validation fails, railway stops here, operation returns
    # false and controller re-renders :new action.
    step Contract::Validate()
    # Sync the valid attributes from the form back to state
    step Contract::Sync(model_key: :todo)
    # Run some additional steps like persisting data, emiting events, notifying
    # internal systems, etc.
    step :persist
    step :send_notifications

    def persist(state)
      state[:todo].save!
    end

    def send_notifications(state)
      # ...
    end
  end
```

_Theres a heck of a lot more, but I'll get to that soon in a proper detailed Wiki guide._


## RDocs

To come.


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bryanrite/operational. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

