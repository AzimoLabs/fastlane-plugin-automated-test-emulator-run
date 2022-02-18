require 'fastlane/plugin/automated_test_emulator_run/version'

module Fastlane
  module AutomatedTestEmulatorRun
    def self.all_classes
      Dir[File.expand_path('**/{actions,factory,provider,helper}/*.rb', File.dirname(__FILE__))]
    end
  end
end

Fastlane::AutomatedTestEmulatorRun.all_classes.each do |current|
  require current
end


