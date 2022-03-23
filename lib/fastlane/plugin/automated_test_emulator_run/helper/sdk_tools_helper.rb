module Fastlane
  module Helper
    class SdkHelper
      def initialize(params)
        @sdk_root_path = params[:SDK_path]
      end

      def command_line_tools_dir
        return "#{@sdk_root_path}/cmdline-tools/latest/bin" if File.exist?("#{@sdk_root_path}/cmdline-tools/latest/bin")

        return tools_dir # Fallback on old tools path
      end

      def tools_dir
        return "#{@sdk_root_path}/tools/bin"
      end

      def platform_tools_dir
        return "#{@sdk_root_path}/platform-tools"
      end

      def emulator_dir
        return "#{@sdk_root_path}/emulator/"
      end

      def adb
        return "#{platform_tools_dir}/adb"
      end

      def avd_manager
        return "#{command_line_tools_dir}/avdmanager"
      end
    end
  end
end