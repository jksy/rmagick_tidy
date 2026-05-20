module RmagickTidy
  class Configuration
    # :off (default), :warn, :raise
    attr_accessor :strict_mode

    def initialize
      @strict_mode = :off
    end
  end

  class OutOfScopeError < StandardError; end
end
