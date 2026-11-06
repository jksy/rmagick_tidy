module RmagickTidy
  module Tracker
    # Set while track runs: walking an ImageList calls its wrapped #each,
    # which would call track again. Nothing track calls creates images.
    TRACKING_KEY = :rmagick_tidy_tracking

    module_function

    def track(result, receiver = nil)
      return result if receiver && result.equal?(receiver)
      return result if Thread.current[TRACKING_KEY]

      Thread.current[TRACKING_KEY] = true
      begin
        register_new_images(result, receiver)
      ensure
        Thread.current[TRACKING_KEY] = false
      end
      result
    end

    def register_new_images(result, receiver)
      # Images the receiver already holds are not new allocations: e.g.
      # ImageList#dup, #[] and #first hand back the same Image objects
      # (RMagick maps one Ruby object to one C image, so identity means
      # shared memory). Registering them would destroy images that may
      # belong to an outer scope or to no scope at all.
      shared = receiver_images(receiver)
      each_image(result) do |img|
        register(img) unless shared.key?(img)
      end
    end

    def receiver_images(receiver)
      images = {}.compare_by_identity
      each_image(receiver) { |img| images[img] = true }
      images
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
