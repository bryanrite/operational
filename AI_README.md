# Operational — AI Agent Reference

This document is for AI coding agents. It describes the exact API of the `operational` gem so you can generate correct code without guessing.

## Architecture

Operational has four components:

1. **Operation** — orchestrates a business process as a railway of steps
2. **Form** — validates and transforms user input, decoupled from models (built on ActiveModel)
3. **Contract** — step helpers that wire forms into operations (Build → Validate → Sync)
4. **Controller** — Rails mixin that runs operations from controller actions

## Operations

Subclass `Operational::Operation`. Define steps with `step`, `pass`, or `fail` at the class level. Call with `.call(state_hash)`. Returns an `Operational::Result`.

```ruby
class CreateArticleOperation < Operational::Operation
  step :build
  step Contract::Build(contract: ArticleForm, model_key: :article)
  step Contract::Validate()
  step Contract::Sync(model_key: :article)
  step :save
  pass :notify    # return value ignored, never derails
  fail :handle    # only runs on failure track

  def build(state)
    state[:article] = Article.new
    # must return truthy to continue, falsy switches to failure track
  end

  def save(state)
    state[:article].save  # returns true/false naturally
  end

  def notify(state)
    # side effect, return value doesn't matter
  end

  def handle(state)
    # runs on failure track
    # return truthy to recover back to success track
    # return falsy to stay on failure track
    false
  end
end
```

### Step types

| Type   | Runs when        | Truthy return         | Falsy return            |
|--------|------------------|-----------------------|-------------------------|
| `step` | On success track | Continue success      | Switch to failure track |
| `fail` | On failure track | Recover to success    | Continue failure        |
| `pass` | On success track | Continue success      | Continue success        |

### Step actions

A step action can be:
- **Symbol** — calls instance method with `(state)` argument
- **Lambda/Proc** — called with `(state)` argument
- **Any object responding to `.call`** — called with `(state)` argument

### State

State is a plain Ruby hash passed to `.call`. It is mutable — steps read from and write to it. The result's state is a frozen duplicate.

```ruby
result = MyOperation.call(user: user, params: params_hash)
```

### Result

```ruby
result.succeeded?  # => true/false
result.failed?     # => true/false
result.state       # => frozen hash
result[:key]       # => shorthand for result.state[:key]
result.operation   # => the operation instance
```

### Nested operations

Use `Nested::Operation` to call one operation from within another. State is merged back. The nested result's `succeeded?` determines if the parent continues on success or failure track.

```ruby
class CreateArticleOperation < Operational::Operation
  class Present < Operational::Operation
    step :init
    step Contract::Build(contract: ArticleForm, model_key: :article)

    def init(state)
      state[:article] = Article.new
    end
  end

  step Nested::Operation(operation: Present)
  step Contract::Validate()
  step Contract::Sync(model_key: :article)
  pass :persist

  def persist(state)
    state[:article].save!
  end
end
```

## Forms

Subclass `Operational::Form`. Uses `ActiveModel::Model`, `ActiveModel::Attributes`, `ActiveModel::Dirty`.

```ruby
class ArticleForm < Operational::Form
  attribute :title, :string
  attribute :body, :string

  validates :title, presence: true
  validates :body, presence: true
end
```

### Form.build

```ruby
Form.build(
  model: nil,              # ActiveModel instance — copies matching attributes to form
  model_persisted: nil,    # override persisted? detection (true/false/nil)
  state: {},               # context hash, available as @state in the form
  build_method: :on_build  # method to call during build
)
```

- Only attributes defined on the form are copied from the model (nil values are skipped)
- State is frozen and stored as `@state`
- If the form defines `on_build(state)`, it is called during build after attribute assignment
- `changes_applied` is called after build so dirty tracking starts clean

### Form.validate

```ruby
form.validate(params_hash)  # => true/false
```

- Converts `ActionController::Parameters` automatically via `to_unsafe_h`
- Only assigns params matching defined attributes (ignores unknown keys)
- Calls `valid?` and returns the result

### Form.sync

```ruby
form.sync(
  model: nil,          # ActiveModel instance — copies matching attributes back
  state: {},           # passed to on_sync
  sync_method: :on_sync  # custom hook method name
)
```

- Copies form attributes to model where attribute names match
- Calls `on_sync(state)` if defined on the form
- Always returns `true`

### Important: do NOT define `#sync` on a form subclass

Defining `#sync` raises `MethodCollision`. Use `#on_sync` instead — it is called automatically during sync.

### Helper methods

- `persisted?` — returns whether the model was persisted at build time
- `other_validators_have_passed?` — returns `errors.blank?`, useful for conditional validators
- `@state` — access the frozen state hash passed at build time

## Contract step helpers

These are used inside operations as step actions. They return lambdas.

### Contract::Build

```ruby
step Contract::Build(
  contract: MyForm,          # required — the form class
  name: :contract,           # state key to store the form instance
  model_key: nil,            # state key containing the model to build from
  model_persisted: nil,      # override persisted? detection
  build_method: :on_build
)
```

Always returns `true`.

### Contract::Validate

```ruby
step Contract::Validate(
  name: :contract,      # state key where the form is stored
  params_path: nil       # nil → state[:params]
                         # :symbol → state[:params][:symbol]
                         # [:a, :b] → state.dig(:a, :b)
)
```

Returns the result of `form.validate(params)` — `true`/`false`.

### Contract::Sync

```ruby
step Contract::Sync(
  name: :contract,       # state key where the form is stored
  model_key: nil,        # state key containing the model to sync to
  sync_method: :on_sync  # custom sync hook method name
)
```

Returns `true` (from `form.sync`).

## Controller mixin

```ruby
class MyController < ApplicationController
  include Operational::Controller

  def create
    if run CreateArticleOperation
      redirect_to @state[:article]
    else
      render :new, status: :unprocessable_entity
    end
  end
end
```

### run(operation, **extras)

- Merges `extras` with default state (`params` and `current_user` if available)
- Calls `operation.call(state)`
- Sets `@state` to the frozen result state
- Returns `result.succeeded?`

### Overridable methods

- `_operational_default_state` — override to inject custom default state
- `_operational_state_variable` — override to change the instance variable name (default: `@state`)

## Errors

| Error class | Raised when |
|---|---|
| `Operational::InvalidContractModel` | Model doesn't respond to `attributes` |
| `Operational::UnknownStepType` | Step action is not a Symbol or callable |
| `Operational::MethodCollision` | Form subclass defines `#sync` instead of `#on_sync` |

## File structure convention

```
app/concepts/<domain>/
  <name>_form.rb
  <name>_operation.rb
```

Example: `app/concepts/article/article_form.rb`, `app/concepts/article/create_article_operation.rb`

## Common patterns

### New/Create with nested Present

```ruby
class CreateThingOperation < Operational::Operation
  class Present < Operational::Operation
    step :init
    step Contract::Build(contract: ThingForm, model_key: :thing)

    def init(state)
      state[:thing] = Thing.new
    end
  end

  step Nested::Operation(operation: Present)
  step Contract::Validate()
  step Contract::Sync(model_key: :thing)
  pass :persist

  def persist(state)
    state[:thing].save!
  end
end
```

Controller uses `CreateThingOperation::Present` for `new` and `CreateThingOperation` for `create`.

### Multi-model form

```ruby
class OrderForm < Operational::Form
  attribute :item_name, :string
  attribute :shipping_address, :string

  def on_build(state)
    self.shipping_address = state[:user]&.default_address
  end

  def on_sync(state)
    state[:shipping].update!(address: shipping_address)
  end
end
```

### State-dependent validation

```ruby
class ArticleForm < Operational::Form
  attribute :published, :boolean
  validate :admin_only_publish

  def admin_only_publish
    if published && !@state[:current_user]&.admin?
      errors.add(:published, "requires admin privileges")
    end
  end
end
```
