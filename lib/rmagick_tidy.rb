require "rmagick"

require "rmagick_tidy/version"
require "rmagick_tidy/configuration"
require "rmagick_tidy/registry"
require "rmagick_tidy/tracker"
require "rmagick_tidy/hook"

module RmagickTidy
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def scope
      Registry.push
      result = yield
      Tracker.keep(result)
      result
    ensure
      Registry.pop_and_destroy
    end
  end
end

RmagickTidy::Hook.install!

require "rmagick_tidy/railtie" if defined?(::Rails::Railtie)
