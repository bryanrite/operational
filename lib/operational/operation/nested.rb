module Operational
  class Operation
    module Nested
      def self.Operation(operation:)
        lambda do |context|
          nested_result = operation.call(context)
          context.merge!(nested_result.context)
          nested_result.succeeded?
        end
      end
    end
  end
end
