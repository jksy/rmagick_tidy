module RmagickTidy
  module Hook
    # Methods we never want to wrap. Most of them either return self, return
    # primitives, or are introspection / lifecycle helpers where wrapping would
    # be wasteful or risk recursion.
    SKIP_INSTANCE_METHODS = %i[
      destroy! destroyed? inspect to_s == eql? hash freeze frozen?
      tainted? untrusted? object_id class itself
    ].freeze

    # Class-level methods on Magick::Image that produce new images.
    CLASS_METHODS = %i[new read ping from_blob read_inline capture constitute combine].freeze

    module_function

    def install!
      return if @installed
      return unless defined?(::Magick::Image)

      install_instance_hook(::Magick::Image)
      install_class_hook(::Magick::Image)

      if defined?(::Magick::ImageList)
        install_instance_hook(::Magick::ImageList)
        install_class_hook(::Magick::ImageList)
      end

      @installed = true
    end

    def install_instance_hook(klass)
      mod = Module.new do
        def self.inspect = "#<RmagickTidy::InstanceHook>"
      end
      method_names = klass.public_instance_methods(false) - SKIP_INSTANCE_METHODS
      method_names.each do |name|
        next if name.to_s.end_with?("=")

        define_wrapper(mod, name)
      end
      klass.prepend(mod)
    end

    def install_class_hook(klass)
      mod = Module.new do
        def self.inspect = "#<RmagickTidy::ClassHook>"
      end
      CLASS_METHODS.each do |name|
        next unless klass.respond_to?(name)

        define_wrapper(mod, name)
      end
      klass.singleton_class.prepend(mod)
    end

    def define_wrapper(mod, name)
      mod.send(:define_method, name) do |*args, **kwargs, &block|
        result = if kwargs.empty?
                   super(*args, &block)
                 else
                   super(*args, **kwargs, &block)
                 end
        ::RmagickTidy::Tracker.track(result, self)
        result
      end
    end
  end
end
