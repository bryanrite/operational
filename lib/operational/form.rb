module Operational
  class Form
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Dirty

    def self.inherited(subclass)
      super
      subclass.instance_variable_set(:@_operational_sync_check_pending, true)
    end

    def self.method_added(method_name)
      super
      if method_name == :sync && @_operational_sync_check_pending
        raise MethodCollision,
          "#{self} defines #sync, which collides with Operational::Form#sync. " \
          "Rename your method to #on_sync — it will be called automatically during sync."
      end
    end

    def self.build(model: nil, model_persisted: nil, state: {}, prepopulate_method: :prepopulate)
      form = new

      if model
        raise InvalidContractModel unless model.respond_to?(:attributes)
        valid_form_attrs = form.attribute_names
        valid_params = model.attributes.slice(*valid_form_attrs).compact
        form.assign_attributes(valid_params)
      end

      form.instance_variable_set(:@_operational_model_persisted, (model_persisted.nil? ? model&.persisted? || false : !!model_persisted))
      form.instance_variable_set(form.send(:_operational_state_variable), state.dup.freeze)
      form.send(prepopulate_method, state) if form.respond_to?(prepopulate_method)
      form.changes_applied if form.respond_to?(:changes_applied)
      form
    end

    def validate(params = {})
      params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
      params = params.with_indifferent_access if params.respond_to?(:with_indifferent_access)
      valid_params = params.slice(*attribute_names)
      assign_attributes(valid_params)
      valid?
    end

    def sync(model: nil, state: {}, sync_method: :on_sync)
      if model
        raise InvalidContractModel unless model.respond_to?(:attributes)
        valid_model_attrs = model.attribute_names
        valid_params = attributes.slice(*valid_model_attrs)
        model.assign_attributes(valid_params)
      end

      send(sync_method, state) if respond_to?(sync_method)
      true
    end

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
