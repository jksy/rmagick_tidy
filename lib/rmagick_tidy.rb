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

    # Takes the images in value out of scope management: no scope destroys
    # them or hands them to an enclosing scope, so they can be cached past
    # the scope that created them. Returns value.
    def detach(value)
      Tracker.detach(value)
    end
  end
end

RmagickTidy::Hook.install!

require "rmagick_tidy/railtie" if defined?(Rails::Railtie)
