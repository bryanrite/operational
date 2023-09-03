require 'spec_helper'

RSpec.describe Operational::Operation::Nested do
  describe ".Operation" do
    let(:nested_class) do
      Class.new(Operational::Operation) do
        step ->(state) { state[:nested] = "state" }
      end
    end

    before do
      stub_const("NestedClass", nested_class)
    end

    let(:state) { { parent: "state" } }

    it "returns a callable step" do
      expect(described_class::Operation(operation: NestedClass)).to respond_to :call
    end

    it "executes the passed in operation" do
      expect(NestedClass).to receive(:call).with(state).and_call_original
      described_class::Operation(operation: NestedClass).call(state)
    end

    it "responds with the result of the passed in operation" do
      expect(described_class::Operation(operation: NestedClass).call(state)).to eq true
    end

    context "if the nested operation returns false" do
      let(:nested_class) do
        Class.new(Operational::Operation) do
          step ->(state) { return false }
        end
      end

      it "responds with false" do
        expect(described_class::Operation(operation: NestedClass).call(state)).to eq false
      end
    end

    it "merges the state of the nested operation with the state" do
      described_class::Operation(operation: NestedClass).call(state)
      expect(state[:parent]).to eq "state"
      expect(state[:nested]).to eq "state"
    end
  end
end
