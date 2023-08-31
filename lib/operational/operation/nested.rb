module Operational
  class Operation
    module Nested
      def self.Operation(operation:)
        lambda do |state|
          nested_result = operation.call(state)
          state.merge!(nested_result.state)
          nested_result.succeeded?
        end
      end
    end
  end
end
