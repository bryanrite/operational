module Operational
  module Controller
    def run(operation, **extras)
      state = (extras || {}).merge(_operational_default_state)
      result = operation.call(state)

      @_operational_result = result
      instance_variable_set(_operational_state_variable, result.state)

      return result.succeeded?
    end

    protected

    def _operational_state_variable
      :@state
    end

    def _operational_default_state
      {}.tap do |hash|
        hash[:current_user] = current_user if self.respond_to?(:current_user)
        hash[:params] = params if self.respond_to?(:params)
      end
    end
  end
end
