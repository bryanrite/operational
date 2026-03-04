module Operational
  class Error < StandardError; end
  class InvalidContractModel < Error; end
  class MethodNotImplemented < Error; end
  class UnknownStepType < Error; end
  class MethodCollision < Error; end
end
