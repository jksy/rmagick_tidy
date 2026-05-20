module RmagickTidy
  module ControllerHelper
    # Use as `around_action :within_rmagick_tidy_scope`.
    def within_rmagick_tidy_scope(&)
      RmagickTidy.scope(&)
    end
  end

  if defined?(::Rails::Railtie)
    class Railtie < ::Rails::Railtie
      initializer "rmagick_tidy.controller" do
        ActiveSupport.on_load(:action_controller) do
          include ::RmagickTidy::ControllerHelper
        end
      end
    end
  end
end
