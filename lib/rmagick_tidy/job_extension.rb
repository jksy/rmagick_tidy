module RmagickTidy
  # Runs every ActiveJob perform inside a scope:
  #
  #   class ThumbnailJob < ApplicationJob
  #     include RmagickTidy::JobExtension
  #   end
  #
  # Only around_perform is used, so ActiveJob itself is not required here.
  module JobExtension
    def self.included(base)
      # Keep nothing: a perform ending in e.g. `img.write(path)` returns an
      # image nobody uses. perform_now still returns perform's value, since
      # run_callbacks ignores what the around callback returns.
      base.around_perform do |_job, block|
        RmagickTidy.scope do
          block.call
          nil
        end
      end
    end
  end
end
