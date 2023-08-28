require "spec_helper"

RSpec.describe Operational::Operation do

  let(:op_class) do
    Class.new(described_class) do

      step ->(state) { state[:step1] = "step1" }
      step :step2

      def step2(state)
        state[:step2] = "step2"
      end
    end
  end

  before do
    stub_const("OpClass", op_class)
  end

  it "returns a Result object" do
    expect(OpClass.call).to be_an Operational::Result
  end

  it "sets the result boolean in the Result object" do
    expect(OpClass.call.succeeded?).to eq true
  end

  it "exposes the context as an array of the result" do
    result = OpClass.call
    expect(result[:step1]).to eq "step1"
    expect(result[:step2]).to eq "step2"
  end

  it "exposes the operation in the result" do
    result = OpClass.call
    expect(result.operation).to be_an OpClass
  end

  context "with different step types" do
    let(:policy_class) do
      Module.new do
        def self.Test()
          ->(state) { state[:track] << 3 }
        end
      end
    end

    let(:op_class_2) do
      Class.new(described_class) do

        step :step1
        step ->(state) { state[:track] << 2; }
        step PolicyClass::Test()

        def step1(state)
          state[:track] << 1
        end
      end
    end

    before do
      stub_const("PolicyClass", policy_class)
      stub_const("OpClass", op_class_2)
    end

    it "executes each type of callable step" do
      result = OpClass.call(track: [])
      expect(result[:track]).to eq [1,2,3]
    end
  end

  context "with shared parent class" do
    let(:op_class_2) do
      Class.new(described_class) do

        step :step3

        def step3(state)
          state[:step3] = "step3"
        end
      end
    end

    before do
      stub_const("OpClass2", op_class_2)
    end

    it "keeps steps isolated to the class instance" do
      result1 = OpClass.call(run: 1)
      result2 = OpClass2.call(run: 2)
      result3 = OpClass.call(run: 3)

      expect(result1.context).to eq ({ run: 1, step1: "step1", step2: "step2" })
      expect(result2.context).to eq ({ run: 2, step3: "step3" })
      expect(result3.context).to eq ({ run: 3, step1: "step1", step2: "step2" })
    end
  end

  context "with a failed step" do
    let(:op_class) do
      Class.new(described_class) do

        step ->(state) { state[:track] = [1]; true }
        step ->(state) { state[:track] << 2; false }
        step ->(state) { state[:track] << 3; true }
        fail ->(state) { state[:track] << 4; false }
        step ->(state) { state[:track] << 5; true }
      end
    end

    it "stops execution at fail step, skipping inbetween steps" do
      expect(OpClass.call[:track]).to eq [1, 2, 4]
    end

    it "sets the result boolean" do
      expect(OpClass.call.succeeded?).to eq false
    end
  end

  context "with a multiple failure steps" do
    let(:op_class) do
      Class.new(described_class) do

        step ->(state) { state[:track] = [1]; true }
        step ->(state) { state[:track] << 2; false }
        fail ->(state) { state[:track] << 3; false }
        fail ->(state) { state[:track] << 4; false }
        step ->(state) { state[:track] << 5; true }
      end
    end

    it "continues to additional fail steps" do
      expect(OpClass.call[:track]).to eq [1, 2, 3, 4]
    end

    it "sets the result boolean" do
      expect(OpClass.call.succeeded?).to eq false
    end
  end

  context "with a recovery step" do
    let(:op_class) do
      Class.new(described_class) do

        step ->(state) { state[:track] = [1]; true }
        step ->(state) { state[:track] << 2; false }
        fail ->(state) { state[:track] << 3; true }
        fail ->(state) { state[:track] << 4; false }
        step ->(state) { state[:track] << 5; true }
      end
    end

    it "continues after fail to the next non-fail step" do
      expect(OpClass.call[:track]).to eq [1, 2, 3, 5]
    end

    it "sets the result boolean" do
      expect(OpClass.call.succeeded?).to eq true
    end
  end

  context "with a pass step" do
    let(:op_class) do
      Class.new(described_class) do

        step ->(state) { state[:track] = [1]; true }
        pass ->(state) { state[:track] << 2; false }
        fail ->(state) { state[:track] << 3; true }
        fail ->(state) { state[:track] << 4; false }
        step ->(state) { state[:track] << 5; true }
      end
    end

    it "disregards the return and continues to next step" do
      expect(OpClass.call[:track]).to eq [1, 2, 5]
    end

    it "sets the result boolean" do
      expect(OpClass.call.succeeded?).to eq true
    end
  end
end
