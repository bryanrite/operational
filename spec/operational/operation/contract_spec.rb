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

      it "allows sending a model" do
        expect(described_class::Build(contract: CreateForm, model_key: :model).call({ model: model })).to eq true
      end

      it "allows specifying the model key" do
        expect(described_class::Build(contract: CreateForm, model_key: :different_model).call({ different_model: model })).to eq true
      end

      it "ensures the model quacks like an Active Model" do
        expect {
          described_class::Build(contract: CreateForm, model_key: :invalid).call({ model: model })
        }.to raise_error Operational::InvalidContractModel
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

      it "allows sending a model" do
        described_class::Build(contract: CreateForm, model_key: :model).call(state)

        expect(described_class::Sync(model_key: :model).call(state)).to eq true
      end

      it "ensures the model quacks like an Active Model" do
        expect {
          described_class::Sync(model_key: :invalid).call(state)
        }.to raise_error Operational::InvalidContractModel
      end
    end
  end
end
