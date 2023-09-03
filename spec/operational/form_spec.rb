require 'spec_helper'

RSpec.describe Operational::Operation do
  let(:form_class) do
    Class.new(Operational::Form) do
      attribute :name, :string
      validates :name, presence: true
    end
  end

  let(:form) { form_class.new }

  it "exposes a persisted method" do
    expect(form).to respond_to(:persisted?)
  end

  %i[attributes attribute_names assign_attributes].each do |attr|
    it "responds to #{attr}" do
      expect(form).to respond_to(attr)
    end
  end
end
