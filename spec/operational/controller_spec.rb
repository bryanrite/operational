require "spec_helper"

RSpec.describe Operational::Controller, type: :controller do

  let!(:op_class) do
    Class.new(Operational::Operation) do
      step ->(state) { state[:step] = "step" }
    end
  end

  let(:controller_class) do
    Class.new do
      include Operational::Controller

      def test
        if run OpClass
          return true
        else
          return false
        end
      end
    end
  end

  let(:request_params) do
    {}
  end

  before do
   stub_const("OpClass", op_class)
  end

  it "exposes a run method" do
    controller = controller_class.new
    expect(controller).to respond_to :run
  end

  it "exposes the state as an instance variable" do
    controller = controller_class.new
    controller.test

    expect(controller.instance_variable_get(:@state)).to be_present
    expect(controller.instance_variable_get(:@state)).to eq ({ step: "step" })
  end

  it "freezes the state" do
    controller = controller_class.new
    controller.test

    expect(controller.instance_variable_get(:@state)).to be_frozen
  end

  context "with params provided by the controller" do
    let(:controller_class) do
      Class.new do
        include Operational::Controller

        def params
          { example: "from_controller" }
        end

        def test
          run OpClass
        end
      end
    end

    it "adds to the operation's state" do
      controller = controller_class.new
      controller.test

      expect(controller.instance_variable_get(:@state)).to eq ({ params: { example: "from_controller" }, step: "step" })
    end
  end

  context "with current_user provided by the controller" do
    let(:controller_class) do
      Class.new do
        include Operational::Controller

        def current_user
          "user_instance"
        end

        def test
          run OpClass
        end
      end
    end

    it "adds to the operation's state" do
      controller = controller_class.new
      controller.test

      expect(controller.instance_variable_get(:@state)).to eq ({ current_user: "user_instance", step: "step" })
    end
  end

  context "with extra state passed in" do
    let(:controller_class) do
      klass = Class.new do
        include Operational::Controller

        def test
          if run OpClass, extra: "extra"
            return true
          else
            return false
          end
        end
      end
    end

    it "adds to the operations state" do
      controller = controller_class.new
      controller.test

      expect(controller.instance_variable_get(:@state)).to eq ({ extra: "extra", step: "step" })
    end
  end

  describe "#_operational_default_state" do
    context "when overriding the default state" do
      let(:controller_class) do
        Class.new do
          include Operational::Controller

          def _operational_default_state
            { admin: true, params: "params" }
          end

          def test
            run OpClass
          end
        end
      end

      it "sets the state with the specified defaults" do
        controller = controller_class.new
        controller.test

        expect(controller.instance_variable_get(:@state)).to eq ({ admin: true,  params: "params", step: "step" })
      end
    end

    context "when extending the default state" do
      let(:controller_class) do
        Class.new do
          include Operational::Controller

          def current_user
            "user_instance"
          end

          def _operational_default_state
            super.merge({ admin: true})
          end

          def test
            run OpClass
          end
        end
      end

      it "sets the state with the specified defaults" do
        controller = controller_class.new
        controller.test

        expect(controller.instance_variable_get(:@state)).to eq ({ admin: true, current_user: "user_instance", step: "step" })
      end
    end
  end

  describe "#_operational_state_variable" do
    let(:controller_class) do
      Class.new do
        include Operational::Controller

        def _operational_state_variable
          :@custom_var
        end

        def test
          run OpClass
        end
      end
    end

    it "sets the state to the custom variable" do
      controller = controller_class.new
      controller.test

      expect(controller.instance_variable_get(:@custom_var)).to eq ({ step: "step" })
      expect(controller.instance_variable_get(:@state)).to be_nil
    end
  end
end
