require 'spec_helper'

RSpec.describe Operational::Operation::Contract do
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

  before do
    stub_const("CreateForm", form_class)
  end

  describe ".Build" do
    let(:state) { {} }

    it "returns a callable step" do
      expect(described_class::Build(contract: CreateForm)).to respond_to :call
    end

    it "sets the contract to the state" do
      described_class::Build(contract: CreateForm).call(state)

      expect(state).to have_key(:contract)
      expect(state[:contract]).to be_a CreateForm
    end

    describe "name" do
      it "allows overriding the state key" do
        described_class::Build(contract: CreateForm, name: :test).call(state)

        expect(state).to have_key(:test)
        expect(state[:test]).to be_a CreateForm
      end
    end

    describe "model_key" do
      let(:model) do
        model_class.new(name: "Test", email: "test@test.com")
      end

      it "defaults to state[:model] when present" do
        expect(described_class::Build(contract: CreateForm).call({ model: model })).to eq true
      end

      it "pre-populates form attributes from the model" do
        state = { model: model }
        described_class::Build(contract: CreateForm).call(state)
        expect(state[:contract].name).to eq "Test"
      end

      it "builds without a model when state[:model] is absent" do
        state = {}
        described_class::Build(contract: CreateForm).call(state)
        expect(state[:contract]).to be_a CreateForm
      end

      it "allows specifying the model key" do
        expect(described_class::Build(contract: CreateForm, model_key: :different_model).call({ different_model: model })).to eq true
      end

      it "raises when the model key is present in state but nil" do
        expect {
          described_class::Build(contract: CreateForm).call({ model: nil })
        }.to raise_error Operational::InvalidContractModel
      end

      it "raises when the model does not quack like an Active Model" do
        expect {
          described_class::Build(contract: CreateForm).call({ model: "not a model" })
        }.to raise_error Operational::InvalidContractModel
      end
    end

    describe "model_persisted" do
      let(:model) { model_class.new(name: "Test") }

      it "overrides persisted? on the form" do
        state = { model: model }
        described_class::Build(contract: CreateForm, model_persisted: true).call(state)
        expect(state[:contract].persisted?).to eq true
      end
    end

    describe "build_method" do
      it "calls a custom build_method during build" do
        form_class = Class.new(Operational::Form) do
          attribute :name, :string
          def custom_build(state)
            self.name = "from custom build"
          end
        end
        state = {}
        described_class::Build(contract: form_class, build_method: :custom_build).call(state)
        expect(state[:contract].name).to eq "from custom build"
      end
    end
  end

  describe ".Validate" do
    let(:state) { { params: { name: "update", email: "update@test.com" }} }

    before :each do
      described_class::Build(contract: CreateForm).call(state)
    end

    it "returns a callable step" do
      expect(described_class::Validate()).to respond_to :call
    end

    describe "name" do
      it "allows overriding the state key" do
        described_class::Build(contract: CreateForm, name: :test).call(state)

        expect(described_class::Validate(name: :test).call(state)).to eq true
        expect(state).to have_key(:test)
        expect(state[:test]).to be_a CreateForm
      end
    end

    describe "params_path" do
      context "with a symbol" do
        let(:state) { { params: { nested: { name: "update" }}} }

        it "uses params subhash" do
          expect(described_class::Validate(params_path: :nested).call(state)).to eq true
        end
      end

      context "with an array" do
        let(:state) { { different: { path: { name: "update" }}} }

        it "uses array to construct nested path from" do
          expect(described_class::Validate(params_path: [:different, :path]).call(state)).to eq true
        end
      end

      context "with a non-matching path" do
        let(:state) { { no_matching_params: true } }

        it "validates the form as normal (with submitted params)" do
          expect(described_class::Validate().call(state)).to eq false
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

        expect(described_class::Sync(name: :test).call(state)).to eq true
        expect(state).to have_key(:test)
        expect(state[:test]).to be_a CreateForm
      end
    end

    describe "model_key" do
      let(:model) do
        model_class.new(name: "Test", email: "test@test.com")
      end

      let(:state) { { model: model, params: { name: "update", email: "update@test.com" }} }

      it "defaults to state[:model] when present" do
        described_class::Build(contract: CreateForm).call(state)

        expect(described_class::Sync().call(state)).to eq true
      end

      it "writes form attributes back to the model" do
        described_class::Build(contract: CreateForm).call(state)
        described_class::Validate().call(state)
        described_class::Sync().call(state)
        expect(model.name).to eq "update"
      end

      it "syncs without a model when state[:model] is absent" do
        state = { params: { name: "update" } }
        described_class::Build(contract: CreateForm).call(state)

        expect(described_class::Sync().call(state)).to eq true
      end

      it "allows specifying the model key" do
        state = { different_model: model, params: { name: "update" } }
        described_class::Build(contract: CreateForm, model_key: :different_model).call(state)
        described_class::Validate().call(state)
        described_class::Sync(model_key: :different_model).call(state)
        expect(model.name).to eq "update"
      end

      it "raises when the model key is present in state but nil" do
        expect {
          described_class::Sync().call(state.merge(model: nil))
        }.to raise_error Operational::InvalidContractModel
      end

      it "raises when the model does not quack like an Active Model" do
        expect {
          described_class::Sync().call(state.merge(model: "not a model"))
        }.to raise_error Operational::InvalidContractModel
      end
    end

    describe "sync_method" do
      it "calls a custom sync_method during sync" do
        form_class = Class.new(Operational::Form) do
          attribute :name, :string
          def custom_sync(state)
            state[:model].email = "synced@test.com"
          end
        end
        state = { model: model, params: { name: "update" } }
        described_class::Build(contract: form_class).call(state)
        described_class::Validate().call(state)
        described_class::Sync(sync_method: :custom_sync).call(state)
        expect(model.email).to eq "synced@test.com"
      end
    end
  end
end
