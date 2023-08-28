module Operational
  class Form
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Dirty

    def persisted?
      @_operational_model_persisted
    end

    def other_validators_have_passed?
      errors.empty?
    end

    def validation_errors_exist?
      !errors.blank?
    end

    def sync(state)
      raise MethodNotImplemented, "Contract::Sync was called without defining a #sync method in the form."
    end
  end
end
