module Fastlane
  module Helper
    class AutomatedTestEmulatorRunHelper
      # class methods that you define here become available in your action
      # as `Helper::AutomatedTestEmulatorRunHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the automated_test_emulator_run plugin helper!")
      end
    end
  end
end
