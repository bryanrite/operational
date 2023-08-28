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

    def self.call(context={})
      instance = self.new
      instance.instance_variable_set(:@_operational_context, context)
      instance.instance_variable_set(:@_operational_path, [])
      instance.instance_variable_set(:@_operational_result, true)

      failure_circuit = false

      instance.send(:_operational_steps).each_with_index do |railway_step, i|
        type, action = railway_step

        next if !failure_circuit && type == :fail
        next if failure_circuit && type != :fail

        result = if action.is_a?(Symbol)
          instance.send(action, instance.send(:_operational_context))
        elsif action.respond_to?(:call)
          action.call(instance.send(:_operational_context))
        else
          raise UnknownStepType
        end

        instance.instance_variable_set(:@_operational_result, result ? true : false)
        instance.instance_variable_get(:@_operational_path) << (result ? true : false)

        failure_circuit = !instance.instance_variable_get(:@_operational_result) && type != :pass
      end

      return Result.new(
        succeeded: (instance.instance_variable_get(:@_operational_result) ? true : false),
        context: instance.instance_variable_get(:@_operational_context),
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

    def _operational_context
      @_operational_context
    end
  end
end
