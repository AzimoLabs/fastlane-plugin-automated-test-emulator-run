module Fastlane
  module Factory

    class ADB_Controller
      attr_accessor :command_stop, :command_start, :command_get_devices, :command_wait_for_device, :command_get_avds
    end

    class AdbControllerFactory
  
        def self.get_adb_controller(params)
          UI.message(["Preparing commands for Android ADB"].join(" ").yellow)

          # Get paths
          path_sdk = "#{params[:SDK_path]}"
          path_android_binary = path_sdk + "/tools/android"
          path_adb = path_sdk + "/platform-tools/adb"

          # ADB shell command parts
          sh_stop_adb = "kill-server"
          sh_start_adb = "start-server"
          sh_devices_adb = "devices | grep [0-9] | tr -s \"\t\" \" | cut -d\""
          sh_wait_for_device_adb = "wait-for-device"
          sh_list_avd_adb = "list avd"

          # Assemble ADB controller
          adb_controller = ADB_Controller.new
          adb_controller.command_stop = [
           path_adb,
           sh_stop_adb
           ].join(" ")
  
          adb_controller.command_start = [
           path_adb,
           sh_start_adb
           ].join(" ")
  
          adb_controller.command_get_devices = [
           path_adb,
           sh_devices_adb
           ].join(" ")
  
          adb_controller.command_wait_for_device = [
           path_adb,
           sh_wait_for_device_adb
           ].join(" ")

          adb_controller.command_get_avds = [
           path_android_binary, 
           sh_list_avd_adb].join(" ").chomp
  
          return adb_controller
        end 
    end
  end
end