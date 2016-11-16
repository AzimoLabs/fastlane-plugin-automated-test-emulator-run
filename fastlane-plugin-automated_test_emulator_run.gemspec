# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/automated_test_emulator_run/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-automated_test_emulator_run'
  spec.version       = Fastlane::AutomatedTestEmulatorRun::VERSION
  spec.author        = %q{Kamil Krzyk}
  spec.email         = %q{krzyk.kamil@gmail.com}

  spec.summary       = %q{Starts n AVDs based on JSON file config. AVDs are created and configured according to user liking before instrumentation test process (started either via shell command or gradle) and killed/deleted after test process finishes.}
  spec.homepage      = "https://github.com/AzimoLabs/fastlane-plugin-automated-test-emulator-run"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'fastlane', '>= 1.98.0'
end
