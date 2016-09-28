# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/automated_test_emulator_run/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-automated_test_emulator_run'
  spec.version       = Fastlane::AutomatedTestEmulatorRun::VERSION
  spec.author        = %q{Kamil Krzyk}
  spec.email         = %q{krzyk.kamil@gmail.com}

  spec.summary       = %q{Allows to wrap gradle task or shell command that runs integrated tests that prepare and starts single AVD before test run. After tests are finished, emulator is killed and deleted.}
  spec.homepage      = "https://github.com/AzimoLabs/fastlane-plugin-automated-test-emulator-run"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # spec.add_dependency 'your-dependency', '~> 1.0.0'

  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'fastlane', '>= 1.98.0'
end
