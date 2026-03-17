<h1 align="center">
  <img src="logo.png" alt="" width="60" valign="middle">
  Operational
</h1>

<p align="center">
  <strong>Lightweight, railway-oriented operation and form objects for business logic.</strong>
</p>

Operational wraps your business logic into **Operations** — small classes with a railway of steps that succeed or fail. Pair them with **Forms** to decouple your UI and APIs from your models and **Contracts** to wire it all together.

One dependency: `activemodel`. ~200 lines of plain ruby code. It's not a framework — it's a pattern. You probably already know how Operational works.

> [!NOTE]
> **AI agents:** See [AI_README.md](AI_README.md) for a concise API reference optimized for code generation.

[![Gem Version](https://img.shields.io/gem/v/operational.svg)](https://rubygems.org/gems/operational)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)


## Table of Contents

- [Quick Example](#quick-example)
- [Installation](#installation)
- [Why You Need Operational](#why-you-need-operational)
- [Core Concepts](#core-concepts)
  - [Operations](#operations)
  - [Forms](#forms)
  - [Contracts](#contracts)
  - [Composing Operations](#composing-operations)
- [Rails Integration](#rails-integration)
- [Project Structure](#project-structure)
- [Full Example](#full-example)
- [Testing](#testing)
- [Requirements](#requirements)
- [Contributing](#contributing)
- [License](#license)

## Quick Example

```ruby
# A form object — validates input without being linked to a specific model.
class SignupForm < Operational::Form
  attribute :name, :string
  attribute :email, :string

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end

# An operation — wires together validation, persistence, and business process with railway functional programming.
class RegisterUserOperation < Operational::Operation
  step :setup
  step Contract::Build(contract: SignupForm)
  step Contract::Validate()
  step Contract::Sync()
  step :persist
  pass :send_welcome

  def setup(state)
    state[:model] = User.new(role: :member)
  end

  def persist(state)
    state[:model].save
  end

  def send_welcome(state)
    WelcomeMailer.welcome(state[:model]).deliver_later
  end
end
```

```ruby
# In your controller — simple boolean branching.
if run RegisterUserOperation
  redirect_to dashboard_path, notice: "Welcome #{@state[:model].name}!"
else
  render :new, status: :unprocessable_entity
end
```

## Installation

Add to your Gemfile:

```ruby
gem 'operational'
```

Then run `bundle install`.

## Why You Need Operational

Rails apps start simple — a model, a controller, some validations. Then the business logic creeps in. "Register a user" isn't just `User.create` anymore — it's validate the input, assign a role, send a welcome email, and notify the sales team. That logic ends up scattered across callbacks, controller actions, and service objects that everyone has to remember to call in the right order.

Operational gives you a place for all of that. Each operation describes a business process as a readable sequence of steps that anyone on the team can follow — no digging through models and callbacks to understand what happens.

**Operational can help when:**

- UI and API requests are touching multiple models (`accepts_nested_attributes_for`)
- Model validations need to change by outside context (e.g., only admins can publish)
- Model callbacks are doing too much (`after_create`, `after_save`, etc.)
- Business processes are duplicated between controllers, jobs, and scripts
- Strong parameters are getting complex with deeply nested or context-dependent permits
- Testing business logic requires full controller/request specs instead of simple unit tests

## Core Concepts

### Operations

An operation is a class that defines a sequence of steps executed in order. Each step either succeeds (returns truthy) or fails (returns falsy), controlling the flow through the railway.

**Operations orchestrate, they don't implement.** Keep your steps thin — they should try to delegate to plain Ruby objects, service classes, and model methods. An operation's job is to define the order things happen and what to do when something fails, in other words, _**orchestrate**_ the business process but don't contain the business logic itself. If a step is getting long, extract the work into a ruby service object and call it from the step.

#### Defining Steps

Steps can be **symbols** (instance methods), **lambdas**, or any **callable** object:

```ruby
class ProcessOrderOperation < Operational::Operation
  step :validate_inventory       # instance method
  step ->(state) { ... }        # lambda
  step Policies::OrderPolicy()  # callable object
end
```

Every step receives a `state` hash and returns a truthy or falsy value.

#### Running an Operation

Call `.call` on the operation with an optional initial state hash. You get back a `Result`:

```ruby
result = ProcessOrderOperation.call(order: order, current_user: user)

result.succeeded?  # => true / false
result.failed?     # => true / false
result.state       # => the full state hash (frozen)
result[:order]     # => shorthand for result.state[:order]
result.operation   # => the operation instance
```

There is intentionally one entry point (`.call`) and one result type. Check `succeeded?` and branch accordingly.

#### The Railway: step, pass, fail

Operations follow a **railway pattern** with two tracks — success and failure:

- **`step`** — Runs on the success track. If it returns falsy, execution switches to the failure track.
- **`fail`** — Runs on the failure track only. If it returns truthy, execution switches back to the success track (recovery).
- **`pass`** — Always runs on the success track and always continues on the success track, regardless of return value. Useful for side effects.

```ruby
class PlaceOrderOperation < Operational::Operation
  step :validate_cart      # success track — runs first
  step :charge_card        # if this returns false → switches to failure track
  step :send_confirmation  # SKIPPED if charge_card failed
  fail :notify_support     # failure track — only runs after a failure
  fail :refund             # continues on failure track
end
```

**Recovery:** If a `fail` step returns truthy, execution moves back to the success track. This lets you handle errors and continue.

**`pass` for side effects:** A `pass` step always continues on the success track regardless of its return value — useful for logging, analytics, or other fire-and-forget work:

```ruby
class PublishArticleOperation < Operational::Operation
  step :publish
  pass :track_analytics    # return value ignored — never derails the operation
  step :notify_subscribers # always runs after pass
end
```

#### State

Every operation revolves around a single **state hash**. It's created when you call the operation, passed to every step, and returned in the result. Steps read from it, write to it, and use it to pass data to each other — similar to how Unix pipes pass data through a chain of commands:

```ruby
result = ChargeOrderOperation.call(params: { id: 1 }, current_user: admin)
#                                 └──────────── initial state ───────────┘

# Each step receives and mutates the same hash:
#   step :find_order    →  state[:order] = Order.find_by(...)
#   step :charge_payment  →  state[:charge] = PaymentGateway.charge(...)

result.state     # => frozen snapshot of the final state
result[:order]   # => the order that was charged
```

This single shared hash means steps are fully decoupled — they don't know about each other, they just read and write to state. You can reorder, add, or remove steps without changing method signatures. And because state is frozen after the operation completes, the result is an immutable snapshot of everything that happened.

#### A Realistic Example

```ruby
class ChargeOrderOperation < Operational::Operation
  step :find_order
  step :charge_payment
  pass :track_analytics
  pass :send_confirmation
  fail :refund

  def find_order(state)
    state[:order] = Order.find_by(id: state[:params][:id])
    state[:order].present?
  end

  def charge_payment(state)
    state[:charge] = PaymentGateway.charge(state[:order].total)
    state[:charge].success?
  end

  def track_analytics(state)
    Analytics.track("order.charged", order_id: state[:order].id)
    # return value doesn't matter — pass always continues
  end

  def send_confirmation(state)
    OrderMailer.confirmation(state[:order]).deliver_later
  end

  def refund(state)
    PaymentGateway.refund(state[:charge]) if state[:charge]
    false
  end
end
```

### Forms

Forms decouple input validation from your models. They allow you to build UI and APIs that aren't coupled to your database modeling and allow you to define exactly what parameters you'll accept in a declarative way.

They're built on `ActiveModel::Model`, `ActiveModel::Attributes`, and `ActiveModel::Dirty` — so you already know the API.

> [!TIP]
> Already familiar with form objects? Skip ahead to [Contracts](#contracts) to see how forms wire into operations.

#### Defining a Form

```ruby
class ArticleForm < Operational::Form
  attribute :title, :string
  attribute :body, :string
  attribute :published, :boolean, default: false

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, presence: true
end
```

#### Building, Validating, and Syncing

The basic lifecycle of a form is **build → validate → sync**. For single-model forms, this is straightforward — pass a model to `.build` and attributes defined in your form matching attributes in the model are automatically copied in both directions:

```ruby
# Build — pre-populates form from the model's matching attributes
article = Article.find(params[:id])
form = ArticleForm.build(model: article)
form.title       # => article.title (auto-copied)
form.persisted?  # => true (detected from model)

# Validate — assigns params, runs validations, returns true/false
form.validate(title: "Updated", body: "New content")  # => true
form.validate(title: "")                               # => false
form.errors.full_messages                              # => ["Title can't be blank"]

# Sync — writes matching attributes back to the model
form.sync(model: article)
article.title  # => "Updated"
```

Any params that don't match a defined form attribute are ignored — no need for `strong_parameters`, your form defines what parameters you will accept.

You can also pass **state** to `.build`, which is separate from the form's attributes — it's not user input, it's context. State is available as `@state` and is useful for conditional validation (e.g., only admins can publish) and prepopulating defaults from things the user doesn't control:

```ruby
form = ArticleForm.build(model: article, state: { current_user: current_user, team: team })
```

> [!NOTE]
> Inside an operation, [`Contract` helpers](#contracts) handle this entire lifecycle as steps — you won't call these methods directly, and state is passed automatically.

#### Multi-Model Forms: on_build and on_sync Hooks

For simple single-model forms, the automatic attribute matching handles everything. For more complex cases — where a single form spans multiple models — you can define `on_build` and `on_sync` hooks to control how data flows in and out:

```ruby
class NewArticleForm < Operational::Form
  attribute :title, :string
  attribute :body, :string
  attribute :author_bio, :string
  attribute :default_category, :string

  # Pull data IN from multiple sources when the form is built
  def on_build(state)
    self.author_bio = state[:current_user]&.bio
    self.default_category = state[:team]&.default_category
  end

  # Push data OUT to multiple models when the form is synced
  def on_sync(state)
    state[:author].update!(bio: author_bio) if author_bio_changed?
  end
end

# Build pulls from article (automatic) + current_user/team (via on_build)
form = NewArticleForm.build(model: article, state: { current_user: user, team: team, author: user })

# Sync writes to article (automatic) + author (via on_sync)
form.sync(model: article, state: { article: article, author: user })
```

#### Dirty Tracking

Forms support ActiveModel dirty tracking out of the box:

```ruby
form = ArticleForm.build(model: article)
form.changed?        # => false (clean after build)

form.title = "New"
form.changed?        # => true
form.title_changed?  # => true
form.title_was       # => "Original Title"
```

#### State-Dependent Validators

Access operation state inside custom validators via `@state`:

```ruby
class ArticleForm < Operational::Form
  attribute :title, :string
  validate :must_be_admin

  def must_be_admin
    errors.add(:base, "Not authorized") unless @state[:current_user]&.admin?
  end
end
```

### Contracts

Contract helpers wire forms into operations as steps. This is where Operations and Forms come together.

#### Contract.Build

Creates a form instance and stores it in the state:

```ruby
# Simple — builds the form and pre-populates from state[:model]
step Contract::Build(contract: ArticleForm)

# With a custom model key — pre-populates from state[:article] instead
step Contract::Build(contract: ArticleForm, model_key: :article)
```

Options:
- `contract:` — the form class (required)
- `name:` — state key to store the form (default: `:contract`)
- `model_key:` — state key containing the model to build from (default: `:model`)
- `model_persisted:` — override `persisted?` detection
- `build_method:` — method to call during build (default: `:on_build`)

#### Contract.Validate

Validates the form using params from the state:

```ruby
# Simple — validates state[:contract] with state[:params]
step Contract::Validate()

# With nested params — validates with state[:params][:article]
step Contract::Validate(params_path: :article)

# With a custom path — validates with state.dig(:custom, :path)
step Contract::Validate(params_path: [:custom, :path])
```

Options:
- `name:` — state key where the form is stored (default: `:contract`)
- `params_path:` — `nil` for `state[:params]`, a symbol for `state[:params][symbol]`, or an array for a custom dig path

Returns `true` if validation passes, `false` otherwise — making it a natural railway step.

#### Contract.Sync

Syncs form data back to a model:

```ruby
# Simple — syncs form attributes back to state[:model]
step Contract::Sync()

# With a custom model key — syncs back to state[:article] instead
step Contract::Sync(model_key: :article)
```

Options:
- `name:` — state key where the form is stored (default: `:contract`)
- `model_key:` — state key containing the model to sync to (default: `:model`)
- `sync_method:` — custom sync hook method name (default: `:on_sync`)

#### Putting It Together

```ruby
# app/concepts/article/article_form.rb
class ArticleForm < Operational::Form
  attribute :title, :string
  attribute :body, :string

  validates :title, presence: true
  validates :body, presence: true
end

# app/concepts/article/create_article_operation.rb
class CreateArticleOperation < Operational::Operation
  step :init
  step Contract::Build(contract: ArticleForm)
  step Contract::Validate()
  step Contract::Sync()
  step :save

  def init(state)
    state[:model] = Article.new
  end

  def save(state)
    state[:model].save
  end
end

# Direct usage
result = CreateArticleOperation.call(params: { title: "Hello", body: "World" })
result.succeeded? # => true
result[:model]    # => #<Article id: 1, title: "Hello", ...>

# From a controller
class ArticlesController < ApplicationController
  include Operational::Controller

  def create
    if run CreateArticleOperation
      redirect_to @state[:model], notice: "Article created!"
    else
      render :new, status: :unprocessable_entity
    end
  end
end
```

### Composing Operations

Just like Rails controllers pair `new`/`create` and `edit`/`update`, operations often share setup logic between actions. `Nested::Operation` lets you extract the common part — building the model, setting up the form — into a reusable operation that gets nested inside the action-specific ones:

```ruby
class CreateArticleOperation < Operational::Operation
  # The "new" part — builds the model and sets up the form
  class Present < Operational::Operation
    step :init
    step Contract::Build(contract: ArticleForm, model_key: :article)

    def init(state)
      state[:article] = Article.new(author: state[:current_user])
    end
  end

  # The "create" part — nests Present, then validates, syncs, and persists
  step Nested::Operation(operation: Present)
  step Contract::Validate()
  step Contract::Sync(model_key: :article)
  pass :persist

  def persist(state)
    ActiveRecord::Base.transaction do
      state[:article].save!
    end
  end
end
```

Use `CreateArticleOperation::Present` for the `new` action and `CreateArticleOperation` for `create` — no need to duplicate setup or extract controller helpers.

## Rails Integration

Include `Operational::Controller` in your controllers to get the `run` helper:

```ruby
class ArticlesController < ApplicationController
  include Operational::Controller

  def create
    if run CreateArticleOperation
      redirect_to @state[:article], notice: "Article created!"
    else
      render :new, status: :unprocessable_entity
    end
  end
end
```

`run` automatically injects `params` and `current_user` (if available) into the operation state, and exposes the result state as `@state`.

You can pass additional state:

```ruby
run CreateArticleOperation, publish: true, category: @category
```

Override `_operational_default_state` to customize what gets injected:

```ruby
class ApplicationController < ActionController::Base
  include Operational::Controller

  protected

  def _operational_default_state
    super.merge(admin: current_user&.admin?)
  end
end
```

## Project Structure

We recommend organizing operations and forms under `app/concepts/`, grouped by the domain concept they belong to:

```
app/
  concepts/
    article/
      article_form.rb
      create_article_operation.rb
      publish_article_operation.rb
    registration/
      signup_form.rb
      register_user_operation.rb
  controllers/
    articles_controller.rb
    registrations_controller.rb
  models/
    article.rb
    user.rb
```

This keeps related operations and forms together — everything about articles lives in `app/concepts/article/`. Rails autoloading picks them up automatically — no configuration needed.

## Full Example

Here's a complete `new`/`create` flow — form, operation, and controller working together:

```ruby
# app/concepts/article/article_form.rb
class ArticleForm < Operational::Form
  attribute :title, :string
  attribute :body, :string

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, presence: true
end

# app/concepts/article/create_article_operation.rb
class CreateArticleOperation < Operational::Operation
  # The "new" part — reusable for the new action
  class Present < Operational::Operation
    step :init
    step Contract::Build(contract: ArticleForm, model_key: :article)

    def init(state)
      state[:article] = Article.new(author: state[:current_user])
    end
  end

  # The "create" part
  step Nested::Operation(operation: Present)
  step Contract::Validate()
  step Contract::Sync(model_key: :article)
  pass :persist

  def persist(state)
    state[:article].save!
  end
end

# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  include Operational::Controller

  def new
    run CreateArticleOperation::Present
  end

  def create
    if run CreateArticleOperation
      redirect_to @state[:article], notice: "Article created!"
    else
      render :new, status: :unprocessable_entity
    end
  end
end
```

The `new` action runs just `Present` to build an empty form. The `create` action nests `Present` then adds validation, syncing, and persistence. The controller only handles HTTP routing — all business logic lives in the operation.

## Testing

Testing Operations and Forms is straightforward. They are plain Ruby objects that can be tested as unit tests — no controller or request specs needed.

### Testing Operations

```ruby
RSpec.describe CreateArticleOperation do
  it "creates an article with valid params" do
    result = CreateArticleOperation.call(
      params: { title: "Test", body: "Content" },
      current_user: create(:user)
    )

    expect(result).to be_succeeded
    expect(result[:article]).to be_persisted
  end

  it "fails with invalid params" do
    result = CreateArticleOperation.call(
      params: { title: "" },
      current_user: create(:user)
    )

    expect(result).to be_failed
    expect(result[:contract].errors[:title]).to include("can't be blank")
  end
end
```

### Testing Forms

```ruby
class ArticleFormTest < Minitest::Test
  def test_validates_presence_of_title
    form = ArticleForm.build
    form.validate(title: "", body: "Content")

    assert_includes form.errors[:title], "can't be blank"
  end

  def test_syncs_attributes_to_the_model
    article = Article.new
    form = ArticleForm.build(model: article)
    form.validate(title: "Updated", body: "New content")
    form.sync(model: article)

    assert_equal "Updated", article.title
  end
end
```

## Requirements

- Ruby >= 3.0
- ActiveModel >= 7.0

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/bryanrite/operational).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
