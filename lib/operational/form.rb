module Operational
  class Form
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Dirty

    def persisted?
      @_operational_model_persisted
    end

    def other_validators_have_passed?
      errors.blank?
    end

    protected

    def _operational_state_variable
      :@state
    end
  end
end
