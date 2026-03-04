module Operational
  class Operation
    module Contract
      def self.Build(contract:, name: :contract, model_key: nil, model_persisted: nil, prepopulate_method: :prepopulate)
        lambda do |state|
          model = model_key.present? ? state[model_key] : nil
          raise InvalidContractModel if model_key.present? && model.nil?

          state[name] = contract.build(
            model: model,
            model_persisted: model_persisted,
            state: state,
            prepopulate_method: prepopulate_method
          )
          true
        end
      end

      def self.Validate(name: :contract, params_path: nil)
        lambda do |state|
          valid_path = case
            when params_path.nil? then [:params]
            when params_path.is_a?(Symbol) then [:params, params_path]
            when params_path.is_a?(Array) then params_path
          end

          raw_params = state.dig(*valid_path) || {}
          state[name].validate(raw_params)
        end
      end

      def self.Sync(name: :contract, model_key: nil, sync_method: :on_sync)
        lambda do |state|
          model = model_key.present? ? state[model_key] : nil
          raise InvalidContractModel if model_key.present? && model.nil?

          state[name].sync(model: model, state: state, sync_method: sync_method)
        end
      end
    end
  end
end
