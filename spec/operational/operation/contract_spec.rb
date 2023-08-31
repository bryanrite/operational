require 'spec_helper'

RSpec.describe Operational::Operation::Contract do
  let(:form_class) do
    Class.new(Operational::Form) do
      attribute :name, :string
      validates :name, presence: true
    end
  end

  before do
    stub_const("CreateForm", form_class)
  end

  describe ".Build" do
    let(:state) { {} }

    it "returns a callable step" do
      expect(described_class::Build(contract: CreateForm)).to respond_to :call
    end

    it "sets the contract to the state" do
      build_step = described_class::Build(contract: CreateForm)
      build_step.call(state)

      expect(state).to have_key(:contract)
      expect(state[:contract]).to be_a CreateForm
    end

    it "does not expose the state variable as an attribute" do
      described_class::Build(contract: CreateForm).call(state)

      expect(state[:contract].instance_variable_get(:@state)).to eq state
      expect(state[:contract].attributes).to_not include :state
    end

    describe "name" do
      it "allows overriding the state key" do
        build_step = described_class::Build(contract: CreateForm, name: :test)
        build_step.call(state)

        expect(state).to have_key(:test)
        expect(state[:test]).to be_a CreateForm
      end
    end

    describe "model_key" do
      let(:model_class) do
        Class.new do
          include ActiveModel::Model
          include ActiveModel::Attributes

          attribute :name, :string
          attribute :email, :string
        end
      end

      let(:model) do
        model_class.new(name: "Test", email: "test@test.com")
      end

      it "allows sending a model" do
        build_step = described_class::Build(contract: CreateForm, model_key: :model)
        expect(build_step.call({ model: model })).to eq true
      end

      it "allows specifying the model key" do
        build_step = described_class::Build(contract: CreateForm, model_key: :different_model)
        expect(build_step.call({ different_model: model })).to eq true
      end

      it "ensures the model quacks like an Active Model" do
        build_step = described_class::Build(contract: CreateForm, model_key: :invalid)
        expect {
          build_step.call({ model: model })
        }.to raise_error Operational::InvalidContractModel
      end

      it "applies the matching attributes from model to contract" do
        state = { model: model }

        build_step = described_class::Build(contract: CreateForm, model_key: :model)
        build_step.call(state)

        expect(state[:contract].name).to eq "Test"
      end
    end

    describe "model_persisted" do
      it "defaults to not persisted" do
        build_step = described_class::Build(contract: CreateForm)
        build_step.call(state)

        expect(state[:contract].persisted?).to eq false
      end

      it "allows setting the persisted value" do
        build_step = described_class::Build(contract: CreateForm, model_persisted: true)
        build_step.call(state)

        expect(state[:contract].persisted?).to eq true
      end

      context "with a persisted model being sent" do
        let(:model_class) do
          Class.new do
            include ActiveModel::Model
            include ActiveModel::Attributes

            attribute :name, :string

            def persisted?
              true
            end
          end
        end

        let(:state) { { model: model_class.new } }

        it "uses the model's persistence by default" do
          build_step = described_class::Build(contract: CreateForm, model_key: :model)
          build_step.call(state)

          expect(state[:contract].persisted?).to eq true
        end

        it "allows overriding the model's persistence" do
          build_step = described_class::Build(contract: CreateForm, model_key: :model, model_persisted: false)
          build_step.call(state)

          expect(state[:contract].persisted?).to eq false
        end

      end

      context "with a non-persisted model being sent" do
        let(:model_class) do
          Class.new do
            include ActiveModel::Model
            include ActiveModel::Attributes

            attribute :name, :string

            def persisted?
              false
            end
          end
        end

        let(:state) { { model: model_class.new } }

        it "uses the model's persistence by default" do
          build_step = described_class::Build(contract: CreateForm, model_key: :model)
          build_step.call(state)

          expect(state[:contract].persisted?).to eq false
        end

        it "allows overriding the model's persistence" do
          build_step = described_class::Build(contract: CreateForm, model_key: :model, model_persisted: true)
          build_step.call(state)

          expect(state[:contract].persisted?).to eq true
        end
      end
    end

    describe "prepopulate_method" do
      let(:form_class) do
        Class.new(Operational::Form) do
          attribute :name, :string

          def prepopulate(state)
            state[:prepopulate] = "test"
          end

          def other_prepopulate(state)
            state[:other_prepopulate] = "test"
          end
        end
      end

      it "runs the prepopulate_method if defined" do
        build_step = described_class::Build(contract: CreateForm)
        build_step.call(state)

        expect(state[:prepopulate]).to eq "test"
        expect(state[:other_prepopulate]).to be_nil
      end

      it "allows overriding the method name" do
        build_step = described_class::Build(contract: CreateForm, prepopulate_method: :other_prepopulate)
        build_step.call(state)

        expect(state[:other_prepopulate]).to eq "test"
        expect(state[:prepopulate]).to be_nil
      end
    end
  end

  describe ".Validate" do
    let(:state) { { params: { name: "update", email: "update@test.com" }} }

    before :each do
      build_step = described_class::Build(contract: CreateForm)
      build_step.call(state)
    end

    it "returns a callable step" do
      expect(described_class::Validate()).to respond_to :call
    end

    it "applies the matching params to the contract" do
      validate_step = described_class::Validate()
      validate_step.call(state)

      expect(state[:contract].name).to eq "update"
    end

    context "when form is valid" do
      it "returns true" do
        validate_step = described_class::Validate()

        expect(validate_step.call(state)).to eq true
      end

      it "return empty error object" do
        validate_step = described_class::Validate()
        validate_step.call(state)

        expect(state[:contract].valid?).to eq true
        expect(state[:contract].errors).to be_empty
      end
    end

    context "when form is invalid" do
      let(:state) { { params: { email: "update@test.com" }} }

      it "returns false" do
        validate_step = described_class::Validate()

        expect(validate_step.call(state)).to eq false
      end

      it "returns error object" do
        validate_step = described_class::Validate()
        validate_step.call(state)

        expect(state[:contract].valid?).to eq false
        expect(state[:contract].errors).to be_present
        expect(state[:contract].errors.full_messages).to eq ["Name can't be blank"]
      end
    end

    context "requiring the state for validiations" do
      let(:form_class) do
        Class.new(Operational::Form) do
          validate :state_is_present_validator

          def state_is_present_validator
            @state.present? &&
            @state.frozen? &&
            @state[:params] == { name: "update", email: "update@test.com" } &&
            @state[:contract] == self
          end
        end
      end

      it "exposes the frozen state via the instance var" do
        expect(described_class::Validate().call(state)).to eq true
      end
    end

    describe "name" do
      it "allows overriding the state key" do
        described_class::Build(contract: CreateForm, name: :test).call(state)

        validate_step = described_class::Validate(name: :test)
        expect(validate_step.call(state)).to eq true

        expect(state).to have_key(:test)
        expect(state[:test]).to be_a CreateForm
      end
    end

    describe "params_path" do
      context "with a symbol" do
        let(:state) { { params: { nested: { name: "update" }}} }

        it "uses params subhash" do
          validate_step = described_class::Validate(params_path: :nested)
          expect(validate_step.call(state)).to eq true
        end
      end

      context "with an array" do
        let(:state) { { different: { path: { name: "update" }}} }

        it "uses array to construct nested path from" do
          validate_step = described_class::Validate(params_path: [:different, :path])
          expect(validate_step.call(state)).to eq true
        end
      end

      context "with a non-matching path" do
        let(:state) { { no_matching_params: true } }

        it "validates the form as normal (with submitted params)" do
          validate_step = described_class::Validate()

          expect(validate_step.call(state)).to eq false
          expect(state[:contract].errors).to be_present
        end
      end
    end
  end

  describe ".Sync" do
    let(:state) { { params: { name: "update", email: "update@test.com" }} }

    before :each do
      described_class::Build(contract: CreateForm).call(state)
    end

    it "returns a callable step" do
      expect(described_class::Sync()).to respond_to :call
    end

    describe "name" do
      it "allows overriding the state key" do
        described_class::Build(contract: CreateForm, name: :test).call(state)

        sync_step = described_class::Sync(name: :test)
        expect(sync_step.call(state)).to eq true

        expect(state).to have_key(:test)
        expect(state[:test]).to be_a CreateForm
      end
    end

    describe "model_key" do
      let(:model_class) do
        Class.new do
          include ActiveModel::Model
          include ActiveModel::Attributes

          attribute :name, :string
          attribute :email, :string
        end
      end

      let(:model) do
        model_class.new(name: "Test", email: "test@test.com")
      end

      let(:state) { { model: model, params: { name: "update", email: "update@test.com" }} }

      it "allows sending a model" do
        described_class::Build(contract: CreateForm, model_key: :model).call(state)

        sync_step = described_class::Sync(model_key: :model)
        expect(sync_step.call(state)).to eq true
      end

      it "ensures the model quacks like an Active Model" do
        sync_step = described_class::Sync(model_key: :invalid)
        expect {
          sync_step.call(state)
        }.to raise_error Operational::InvalidContractModel
      end

      it "applies the matching attributes from contract to model" do
        described_class::Build(contract: CreateForm, model_key: :model).call(state)
        described_class::Validate().call(state)
        described_class::Sync(model_key: :model).call(state)

        expect(state[:model].name).to eq state[:params][:name]
        expect(state[:model].email).to eq model.email
      end
    end

    describe "sync_method" do
      let(:form_class) do
        Class.new(Operational::Form) do
          attribute :name, :string

          def sync(state)
            state[:sync] = "test"
          end

          def other_sync(state)
            state[:other_sync] = "test"
          end
        end
      end

      it "runs the sync_method if defined" do
        described_class::Build(contract: CreateForm).call(state)
        described_class::Sync().call(state)

        expect(state[:sync]).to eq "test"
        expect(state[:other_sync]).to be_nil
      end

      it "allows overriding the method name" do
        described_class::Build(contract: CreateForm).call(state)
        described_class::Sync(sync_method: :other_sync).call(state)

        expect(state[:other_sync]).to eq "test"
        expect(state[:sync]).to be_nil
      end
    end
  end
end
