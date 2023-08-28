module Operational
  class Result
    def initialize(succeeded:, context:, operation:)
      @succeeded = succeeded
      @context = context.dup.freeze
      @operation = operation
    end

    def succeeded?
      @succeeded
    end

    def failed?
      !@succeeded
    end

    def operation
      @operation
    end

    def context
      @context
    end

    def [](i)
      @context[i]
    end
  end
end
