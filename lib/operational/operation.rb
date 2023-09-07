module Operational
  class Operation
    def self.step(action)
      add_step(:step, action)
    end

    def self.pass(action)
      add_step(:pass, action)
    end

    def self.fail(action)
      add_step(:fail, action)
    end

    def self.call(state={})
      instance = self.new
      instance.instance_variable_set(:@_operational_state, state)
      instance.instance_variable_set(:@_operational_path, [])
      instance.instance_variable_set(:@_operational_succeeded, true)

      failure_circuit = false

      instance.send(:_operational_steps).each do |railway_step|
        type, action = railway_step

        next if !failure_circuit && type == :fail
        next if failure_circuit && type != :fail

        result = if action.is_a?(Symbol)
          instance.send(action, instance.send(:_operational_state))
        elsif action.respond_to?(:call)
          action.call(instance.send(:_operational_state))
        else
          raise UnknownStepType
        end

        result = true if type == :pass
        instance.instance_variable_set(:@_operational_succeeded, result ? true : false)
        instance.instance_variable_get(:@_operational_path) << (result ? true : false)

        failure_circuit = !instance.instance_variable_get(:@_operational_succeeded) && type != :pass
      end

      return Result.new(
        succeeded: (instance.instance_variable_get(:@_operational_succeeded) ? true : false),
        state: instance.instance_variable_get(:@_operational_state),
        operation: instance)
    end

    private

    def self.add_step(type, action)
      railway = class_variable_defined?(:@@_operational_steps) ? class_variable_get(:@@_operational_steps) : []
      railway << [type, action]
      class_variable_set(:@@_operational_steps, railway)
    end

    def _operational_steps
      self.class.class_variable_defined?(:@@_operational_steps) ? self.class.class_variable_get(:@@_operational_steps) : []
    end

    def _operational_state
      @_operational_state
    end
  end
end
