module Fastlane
  module Factory

    class AVD_Controller
        attr_accessor :command_create_avd, :command_start_avd, :command_delete_avd, :command_get_property, :command_kill_device
    end

    class AvdControllerFactory
  
        def self.get_avd_controller(params, avd_scheme)
          UI.message(["Preparing parameters and commands for emulator:", avd_scheme.avd_name].join(" ").yellow)

          path_sdk = "#{params[:SDK_path]}"
          path_android_binary = path_sdk + "/tools/android"
          path_adb = path_sdk + "/platform-tools/adb"

          # create AVD shell command parts
          sh_create_answer_no = "echo \"no\" |"
          sh_create_avd = "create avd"
          sh_create_avd_name = ["--name \"", avd_scheme.avd_name, "\""].join("")
          sh_create_avd_hardware_config_filepath = avd_scheme.create_avd_hardware_config_filepath
          sh_create_avd_additional_options = avd_scheme.create_avd_additional_options

          if avd_scheme.create_avd_target.eql? "" 
            sh_create_avd_target = ""
          else
            sh_create_avd_target = ["--target \"", avd_scheme.create_avd_target, "\""].join("")
          end

          if avd_scheme.create_avd_abi.eql? "" 
            sh_create_avd_abi = ""
          else
            sh_create_avd_abi = ["--abi ", avd_scheme.create_avd_abi].join("")
          end
          
          # launch AVD shell command parts
          sh_launch_emulator_binray = [path_sdk, "/tools/", avd_scheme.launch_avd_launch_binary_name].join("")
          sh_launch_avd_name = ["-avd ", avd_scheme.avd_name].join("")
          sh_launch_avd_additional_options = avd_scheme.launch_avd_additional_options
          
          if avd_scheme.launch_avd_snapshot_filepath.eql? ""
             sh_launch_avd_snapshot = ""
          else
             sh_launch_avd_snapshot = ["-wipe-data -initdata ", avd_scheme.launch_avd_snapshot_filepath].join("")
          end
    
          if avd_scheme.launch_avd_port.eql? ""
            UI.message("PORT AUTO-ASSIGNING - NOT IMPLEMENTED YET".red)
            #port = get_unused_even_tcp_port(5556, 5586)
          else 
            port = avd_scheme.launch_avd_port
          end    
          sh_launch_avd_port = ["-port", port].join(" ")    

          # re-create AVD shell command parts
          sh_delete_avd = ["delete avd -n ", avd_scheme.avd_name].join("")

          # adb related shell command parts
          sh_specific_device = "-s"
          sh_device_name_adb = ["emulator-", port].join("")
          sh_get_property = "shell getprop"
          sh_kill_device = "emu kill"

          # assemble AVD controller
          avd_controller = AVD_Controller.new
          avd_controller.command_create_avd = [
           sh_create_answer_no, 
           path_android_binary, 
           sh_create_avd, 
           sh_create_avd_name, 
           sh_create_avd_target, 
           sh_create_avd_abi, 
           sh_create_avd_hardware_config_filepath, 
           sh_create_avd_additional_options].join(" ")

          avd_controller.command_start_avd = [
           sh_launch_emulator_binray, 
           sh_launch_avd_port, 
           sh_launch_avd_name, 
           sh_launch_avd_snapshot, 
           sh_launch_avd_additional_options, 
           "&>/dev/null &"].join(" ")

          avd_controller.command_delete_avd = [
           path_android_binary,
           sh_delete_avd].join(" ")

          avd_controller.command_get_property = [
           path_adb,
           sh_specific_device,
           sh_device_name_adb,
           sh_get_property].join(" ")

          avd_controller.command_kill_device = [
           path_adb,
           sh_specific_device,
           sh_device_name_adb,
           sh_kill_device,
           "&>/dev/null"].join(" ")

          return avd_controller
        end 

        def self.get_unused_even_tcp_port(min_port, max_port) 
          if min_port % 2 != 0
            min_port += 1
          end

          if max_port % 2 != 0
            max_port += 1
          end

          port = min_port
          while port < max_port  do
             unless system(["lsof -i:", port].join(""), out: '/dev/null')
                break
             end
             port += 2
          end

          return port
        end
    end
  end
end