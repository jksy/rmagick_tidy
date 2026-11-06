module RmagickTidy
  class Configuration
    # :off (default), :warn, :raise
    attr_accessor :strict_mode

    # Receives strict_mode :warn messages via #warn (e.g. Rails.logger).
    # nil (default) falls back to Kernel#warn, i.e. stderr.
    attr_accessor :logger

    def initialize
      @strict_mode = :off
      @logger = nil
    end
  end

  class OutOfScopeError < StandardError; end
end
