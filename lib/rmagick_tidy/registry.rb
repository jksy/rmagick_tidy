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
    rescue StandardError
      # Swallow secondary destroy errors (e.g. Magick::DestroyedImageError on
      # races); the goal is to free what we can without raising from `ensure`.
      nil
    end
  end
end
