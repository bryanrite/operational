module Operational
  class Result
    def initialize(succeeded:, state:, operation:)
      @succeeded = succeeded
      @state = state.dup.freeze
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

    def state
      @state
    end

    def [](i)
      @state[i]
    end
  end
end
