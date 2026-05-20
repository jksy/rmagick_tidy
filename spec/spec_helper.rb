if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/vendor/"
  end
end

require "rmagick_tidy"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.before(:each) do
    Thread.current[RmagickTidy::Registry::STACK_KEY] = []
    RmagickTidy.configuration.strict_mode = :off
  end
end

# Helper for tests: build a tiny in-memory image.
module RmagickTidyTestHelpers
  def make_image(w = 4, h = 4, color = "white")
    Magick::Image.new(w, h) { |opt| opt.background_color = color }
  end
end

RSpec.configure { |c| c.include RmagickTidyTestHelpers }
