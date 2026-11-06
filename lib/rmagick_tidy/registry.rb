module RmagickTidy
  class Scope
    attr_reader :images, :keeps

    def initialize
      @images = []
      @keeps = {}.compare_by_identity
    end

    def register(image)
      @images << image
    end

    def keep(image)
      @keeps[image] = true
    end

    def keep?(image)
      @keeps.key?(image)
    end
  end

  module Registry
    STACK_KEY = :rmagick_tidy_stack

    module_function

    def stack
      Thread.current[STACK_KEY] ||= []
    end

    def current
      stack.last
    end

    def in_scope?
      !stack.empty?
    end

    def push
      stack.push(Scope.new)
    end

    def pop_and_destroy
      scope = stack.pop
      return unless scope

      # A kept image this scope registered moves to the enclosing scope, so
      # an image returned from a nested scope is still released when the
      # outer one ends. Tracker never registers an image twice, so nothing
      # else would hand it over. Kept images registered by an outer scope
      # are not in scope.images and stay with their owner.
      parent = current
      seen = {}.compare_by_identity
      scope.images.each do |img|
        next if seen[img]

        seen[img] = true
        if scope.keep?(img)
          parent&.register(img)
        else
          destroy_safely(img)
        end
      end
      nil
    end

    def destroy_safely(img)
      return unless img
      return if img.respond_to?(:destroyed?) && img.destroyed?

      img.destroy!
    rescue ::Magick::ImageMagickError
      # Swallow Magick-side destroy errors (e.g. DestroyedImageError on races);
      # the goal is to free what we can without raising from `ensure`. Other
      # exceptions (NoMethodError, ArgumentError, etc.) are intentionally not
      # caught here so unrelated bugs surface early.
      nil
    end
  end
end
