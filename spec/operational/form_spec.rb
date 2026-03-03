require 'spec_helper'

RSpec.describe Operational::Form do
  let(:model_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :name, :string
      attribute :email, :string
    end
  end

  let(:form_class) do
    Class.new(Operational::Form) do
      attribute :name, :string
      validates :name, presence: true
    end
  end

  let(:form) { form_class.new }

  it "exposes a persisted method" do
    expect(form).to respond_to(:persisted?)
  end

  %i[attributes attribute_names assign_attributes].each do |attr|
    it "responds to #{attr}" do
      expect(form).to respond_to(attr)
    end
  end

  describe ".build" do
    it "returns an instance of the form" do
      form = form_class.build
      expect(form).to be_a form_class
    end

    describe "model" do
      let(:model) { model_class.new(name: "Test", email: "test@test.com") }

      it "prepopulates matching attributes from the model" do
        form = form_class.build(model: model)
        expect(form.name).to eq "Test"
      end

      it "ignores model attributes that don't exist on the form" do
        form = form_class.build(model: model)
        expect(form.attributes).to_not have_key("email")
      end

      it "skips nil model attributes to preserve form defaults" do
        form_with_default = Class.new(Operational::Form) do
          attribute :name, :string, default: "Default"
        end

        model = model_class.new(name: nil)
        form = form_with_default.build(model: model)
        expect(form.name).to eq "Default"
      end

      it "raises InvalidContractModel when model doesn't quack like ActiveModel" do
        expect {
          form_class.build(model: "not a model")
        }.to raise_error Operational::InvalidContractModel
      end
    end

    describe "model_persisted" do
      it "defaults to false when no model given" do
        form = form_class.build
        expect(form.persisted?).to eq false
      end

      it "detects persistence from the model" do
        persisted_model_class = Class.new do
          include ActiveModel::Model
          include ActiveModel::Attributes
          attribute :name, :string
          def persisted? = true
        end

        form = form_class.build(model: persisted_model_class.new)
        expect(form.persisted?).to eq true
      end

      it "allows explicit override" do
        form = form_class.build(model_persisted: true)
        expect(form.persisted?).to eq true
      end

      it "overrides model persistence when explicitly set" do
        persisted_model_class = Class.new do
          include ActiveModel::Model
          include ActiveModel::Attributes
          attribute :name, :string
          def persisted? = true
        end

        form = form_class.build(model: persisted_model_class.new, model_persisted: false)
        expect(form.persisted?).to eq false
      end
    end

    describe "state" do
      it "attaches frozen state" do
        form = form_class.build(state: { key: "value" })
        frozen_state = form.instance_variable_get(:@state)

        expect(frozen_state).to be_frozen
        expect(frozen_state[:key]).to eq "value"
      end

      it "defaults to empty frozen hash" do
        form = form_class.build
        frozen_state = form.instance_variable_get(:@state)

        expect(frozen_state).to be_frozen
        expect(frozen_state).to eq({})
      end
    end

    describe "prepopulate" do
      let(:form_class) do
        Class.new(Operational::Form) do
          attribute :name, :string

          def prepopulate(state)
            self.name = "prepopulated"
          end
        end
      end

      it "calls prepopulate if defined" do
        form = form_class.build
        expect(form.name).to eq "prepopulated"
      end

      it "allows overriding the prepopulate method name" do
        form_class = Class.new(Operational::Form) do
          attribute :name, :string

          def custom_prepopulate(state)
            self.name = "custom"
          end
        end

        form = form_class.build(prepopulate_method: :custom_prepopulate)
        expect(form.name).to eq "custom"
      end
    end

    describe "dirty tracking" do
      let(:model) { model_class.new(name: "Original") }

      it "resets dirty tracking after build" do
        form = form_class.build(model: model)

        expect(form.changed?).to be false
        expect(form.changes).to be_empty
      end

      it "tracks changes after build" do
        form = form_class.build(model: model)
        form.name = "Changed"

        expect(form.changed?).to be true
        expect(form.name_changed?).to be true
        expect(form.name_was).to eq "Original"
      end
    end
  end

  describe "#validate" do
    it "assigns matching params and runs validations" do
      form = form_class.build
      result = form.validate(name: "Test")

      expect(result).to eq true
      expect(form.name).to eq "Test"
    end

    it "returns false when invalid" do
      form = form_class.build
      result = form.validate(name: "")

      expect(result).to eq false
      expect(form.errors.added?(:name, :blank)).to eq true
    end

    it "filters params to valid attribute names" do
      form = form_class.build
      form.validate(name: "Test", unknown: "ignored")

      expect(form.name).to eq "Test"
      expect(form.attributes).to_not have_key("unknown")
    end

    it "handles ActionController::Parameters" do
      params_class = Class.new(Hash) do
        def to_unsafe_h = to_h
      end

      params = params_class[name: "Test"]
      form = form_class.build
      result = form.validate(params)

      expect(result).to eq true
      expect(form.name).to eq "Test"
    end

    it "works with state-dependent validators" do
      form_class = Class.new(Operational::Form) do
        attribute :name, :string
        validate :must_have_context

        def must_have_context
          errors.add(:base, "no context") unless @state[:context]
        end
      end

      form = form_class.build(state: { context: true })
      expect(form.validate(name: "Test")).to eq true

      form = form_class.build(state: {})
      expect(form.validate(name: "Test")).to eq false
    end
  end

  describe "#sync" do
    let(:model) { model_class.new(name: "Original", email: "original@test.com") }

    it "syncs matching attributes to the model" do
      form = form_class.build(model: model)
      form.validate(name: "Updated")
      form.sync(model: model)

      expect(model.name).to eq "Updated"
    end

    it "only syncs attributes that exist on the model" do
      form = form_class.build(model: model)
      form.validate(name: "Updated")
      form.sync(model: model)

      expect(model.email).to eq "original@test.com"
    end

    it "returns true" do
      form = form_class.build
      expect(form.sync).to eq true
    end

    it "raises InvalidContractModel when model doesn't quack like ActiveModel" do
      form = form_class.build
      expect {
        form.sync(model: "not a model")
      }.to raise_error Operational::InvalidContractModel
    end

    it "works without a model" do
      form = form_class.build
      expect(form.sync).to eq true
    end

    describe "on_sync hook" do
      let(:form_class) do
        Class.new(Operational::Form) do
          attribute :name, :string

          def on_sync(state)
            state[:synced] = true
          end
        end
      end

      it "calls on_sync with state" do
        state = {}
        form = form_class.build
        form.sync(state: state)

        expect(state[:synced]).to eq true
      end

      it "calls on_sync with model and state" do
        state = {}
        form = form_class.build(model: model)
        form.validate(name: "Updated")
        form.sync(model: model, state: state)

        expect(model.name).to eq "Updated"
        expect(state[:synced]).to eq true
      end

      it "allows overriding the sync method name" do
        form_class = Class.new(Operational::Form) do
          attribute :name, :string

          def custom_sync(state)
            state[:custom] = true
          end
        end

        state = {}
        form = form_class.build
        form.sync(state: state, sync_method: :custom_sync)

        expect(state[:custom]).to eq true
      end
    end
  end

  describe "MethodCollision" do
    it "raises when a subclass defines #sync" do
      expect {
        Class.new(Operational::Form) do
          def sync(state)
          end
        end
      }.to raise_error Operational::MethodCollision, /Rename your method to #on_sync/
    end
  end
end
