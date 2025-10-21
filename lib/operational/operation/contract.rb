module Operational
  class Operation
    module Contract
      def self.Build(contract:, name: :contract, model_key: nil, model_persisted: nil, prepopulate_method: :prepopulate)
        lambda do |state|
          state[name] = contract.new

          if model_key.present?
            raise InvalidContractModel if !state[model_key]&.respond_to?(:attributes)
            valid_form_attrs = state[name].attribute_names
            valid_params = state[model_key].attributes.slice(*valid_form_attrs).compact
            state[name].assign_attributes(valid_params)
          end

          state[name].instance_variable_set(:@_operational_model_persisted, (model_persisted.nil? ? state[model_key]&.persisted? || false : !!model_persisted))
          state[name].instance_variable_set(state[name].send(:_operational_state_variable), state.dup.freeze)
          state[name].send(prepopulate_method, state) if state[name].respond_to?(prepopulate_method)
          return true
        end
      end

      def self.Validate(name: :contract, params_path: nil)
        lambda do |state|
          valid_path = case
            when params_path.nil? then [:params]
            when params_path.is_a?(Symbol) then [:params, params_path]
            when params_path.is_a?(Array) then params_path
          end

          valid_attrs = state[name].attribute_names

          raw_params = state.dig(*valid_path) || {}
          raw_params = raw_params.to_unsafe_h if raw_params.respond_to?(:to_unsafe_h)
          raw_params = raw_params.with_indifferent_access

          valid_params = raw_params.slice(*valid_attrs)

          state[name].assign_attributes(valid_params)
          state[name].valid?
        end
      end

      def self.Sync(name: :contract, model_key: nil, sync_method: :sync)
        lambda do |state|
          if model_key.present?
            raise InvalidContractModel if !state[model_key]&.respond_to?(:attributes)
            valid_model_attrs = state[model_key].attribute_names
            valid_params = state[name].attributes.slice(*valid_model_attrs)
            state[model_key].assign_attributes(valid_params)
          end

          state[name].send(sync_method, state) if state[name].respond_to?(sync_method)
          return true
        end
      end
    end
  end
end
