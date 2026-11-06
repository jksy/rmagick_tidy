module RmagickTidy
  module Tracker
    # Every Image that has passed through track, held weakly and compared by
    # identity (RMagick maps one Ruby object to one C image). An image seen
    # before is not a new allocation, whichever method hands it back:
    # ImageList#dup, #[], #first share the list's images, and #pop, #shift,
    # #delete return ones taken out of it. Registering those would destroy
    # images that belong to an outer scope or to no scope at all.
    SEEN = ObjectSpace::WeakMap.new

    # Images taken out of scope management by RmagickTidy.detach, held
    # weakly like SEEN. No scope destroys them or hands them over.
    DETACHED = ObjectSpace::WeakMap.new

    module_function

    def track(result, receiver = nil)
      return result if receiver && result.equal?(receiver)

      each_image(result) do |img|
        next if SEEN.key?(img)

        SEEN[img] = true
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

    def detach(value)
      each_image(value) do |img|
        DETACHED[img] = true
      end
      value
    end

    def detached?(img)
      DETACHED.key?(img)
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
