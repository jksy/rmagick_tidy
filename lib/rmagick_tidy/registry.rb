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
      scope = Scope.new
      stack.push(scope)
      scope
    end

    # Removes +scope+ (the innermost one when nil) from +from+ and destroys
    # its images. Removing a given scope rather than whatever is on top lets
    # Middleware leave its scope open past the block-based scopes around it
    # (until the response body is closed) without either one ending the
    # other's scope. +from+ is the stack the scope was pushed onto, in case
    # the body is closed on another thread or fiber.
    def pop_and_destroy(scope = nil, from: stack)
      scope = scope ? from.delete(scope) : from.pop
      return unless scope

      seen = {}.compare_by_identity
      scope.images.each do |img|
        next if seen[img]

        seen[img] = true
        next if scope.keep?(img)

        destroy_safely(img)
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
