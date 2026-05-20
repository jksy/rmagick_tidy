module RmagickTidy
  module Tracker
    module_function

    def track(result, receiver = nil)
      return result if receiver && result.equal?(receiver)

      each_image(result) do |img|
        register(img)
      end
      result
    end

    def keep(value)
      scope = Registry.current
      return unless scope

      each_image(value) do |img|
        scope.keep(img)
      end
    end

    def each_image(value, &block)
      case value
      when nil
        # nothing
      when ->(v) { defined?(Magick::Image) && v.is_a?(Magick::Image) }
        yield value
      when ->(v) { defined?(Magick::ImageList) && v.is_a?(Magick::ImageList) }
        value.each { |i| yield i if defined?(Magick::Image) && i.is_a?(Magick::Image) }
      when Array
        value.each { |v| each_image(v, &block) }
      when Hash
        value.each_value { |v| each_image(v, &block) }
      end
    end

    def register(img)
      scope = Registry.current
      if scope
        scope.register(img)
      else
        handle_out_of_scope(img)
      end
    end

    def handle_out_of_scope(img)
      case RmagickTidy.configuration.strict_mode
      when :raise
        raise OutOfScopeError,
              "Magick::Image #{img.inspect} was created outside of RmagickTidy.scope"
      when :warn
        warn "[rmagick_tidy] Magick::Image created outside of RmagickTidy.scope (#{img.class})"
      end
    end
  end
end
