describe Fastlane::Actions::AutomatedTestEmulatorRunXingAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The automated_test_emulator_run plugin is working!")

      Fastlane::Actions::AutomatedTestEmulatorRunXingAction.run(nil)
    end
  end
end
