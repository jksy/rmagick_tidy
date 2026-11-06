module RmagickTidy
  module Sidekiq
    # Sidekiq server middleware that runs every job inside a scope:
    #
    #   Sidekiq.configure_server do |config|
    #     config.server_middleware do |chain|
    #       chain.add RmagickTidy::Sidekiq::ServerMiddleware
    #     end
    #   end
    #
    # Sidekiq itself is not required here.
    class ServerMiddleware
      def call(_job_instance, _job_payload, _queue)
        # Sidekiq ignores the return value, so keep nothing.
        RmagickTidy.scope do
          yield
          nil
        end
      end
    end
  end
end
