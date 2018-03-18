require 'open3'
require 'json'

module Fastlane
  module Actions

      class AutomatedTestEmulatorRunAction < Action
        def self.run(params)
          UI.message("The automated_test_emulator_run plugin is working!")

          # Parse JSON with AVD launch confing to array of AVD_scheme objects
          avd_schemes = Provider::AvdSchemeProvider.get_avd_schemes(params)

          # ADB, AVD helper classes
          adb_controller = Factory::AdbControllerFactory.get_adb_controller(params)
          avd_controllers = []

          # Create AVD_Controller class for each AVD_scheme
          for i in 0...avd_schemes.length 
            avd_controller = Factory::AvdControllerFactory.get_avd_controller(params, avd_schemes[i])
            avd_controllers << avd_controller

            if params[:verbose] 
              # Checking for output files
              if File.exists?(avd_controller.output_file.path) 
                UI.message([
                  "Successfully created tmp output file for AVD:", 
                  avd_schemes[i].avd_name + ".", 
                  "File: " + avd_controller.output_file.path].join(" ").green)
              else
                UI.message([
                  "Unable to create output file for AVD:", 
                  avd_schemes[i].avd_name + ".", 
                  "Output will be delegated to null and lost. Check your save/read permissions."].join(" ").red)
              end
            end
          end

          # Reseting wait states
          all_avd_launched = false
          adb_launch_complete = false 
          param_launch_complete = false

          while(!all_avd_launched)
            # Preparation
            UI.message("Configuring environment in order to launch emulators: ".yellow)
            UI.message("Getting avaliable AVDs".yellow)
            devices = Action.sh(adb_controller.command_get_avds)
            packages = Action.sh(adb_controller.command_get_installed_packages)

            for i in 0...avd_schemes.length
              unless packages.match(avd_schemes[i].create_avd_package + "\\s*|").nil?
                UI.message(["Missing package ", avd_schemes[i].create_avd_package, " installing..."].join("").yellow)
                Action.sh(avd_controllers[i].command_install_package)
              else
                UI.message(["Package ", avd_schemes[i].create_avd_package, " already installed"].join("").yellow)
              end

              unless devices.match(avd_schemes[i].avd_name).nil?
                UI.message(["AVD with name '", avd_schemes[i].avd_name, "' currently exists."].join("").yellow)
                if params[:AVD_recreate_new]
                  # Delete existing AVDs
                  UI.message("AVD_create_new parameter set to true.".yellow)
                  UI.message(["Deleting existing AVD with name:", avd_schemes[i].avd_name].join(" ").yellow)
                  Action.sh(avd_controllers[i].command_delete_avd)
                 
                  # Re-create AVD
                  UI.message(["Re-creating new AVD."].join(" ").yellow)
                  Action.sh(avd_controllers[i].command_create_avd)
                else 
                  # Use existing AVD
                  UI.message("AVD_recreate_new parameter set to false.".yellow)
                  UI.message("Using existing AVD for tests.".yellow)
                end
              else 
                # Create AVD
                UI.message(["AVD with name '", avd_schemes[i].avd_name, "' does not exist. Creating new AVD."].join("").yellow)
                Action.sh(avd_controllers[i].command_create_avd)
              end
            end

            # Restart ADB
            if params[:ADB_restart]
              UI.message("Restarting adb".yellow)
              Action.sh(adb_controller.command_stop)
              Action.sh(adb_controller.command_start)
            else
              UI.message("ADB won't be restarted. 'ADB_restart' set to false.".yellow)
            end

            # Applying custom configs (it's not done directly after create because 'cat' operation seems to fail overwrite)
            for i in 0...avd_schemes.length
              UI.message(["Attemting to apply custom config to ", avd_schemes[i].avd_name].join("").yellow)
              if avd_controllers[i].command_apply_config_avd.eql? "" 
                 UI.message(["No config file found for AVD '", avd_schemes[i].avd_name, "'. AVD won't have config.ini applied."].join("").yellow)
              else
                UI.message(["Config file found! Applying custom config to: ", avd_schemes[i].avd_name].join("").yellow)
                Action.sh(avd_controllers[i].command_apply_config_avd)
              end
            end

            # Launching AVDs
            UI.message("Launching all AVDs at the same time.".yellow)
            for i in 0...avd_controllers.length
              Process.fork do
                Action.sh(avd_controllers[i].command_start_avd)
              end
            end

            # Wait for AVDs finish booting
            UI.message("Waiting for AVDs to finish booting.".yellow)
            UI.message("Performing wait for ADB boot".yellow)
            adb_launch_complete = wait_for_emulator_boot_by_adb(adb_controller, avd_schemes, "#{params[:AVD_adb_launch_timeout]}")

            # Wait for AVD params finish booting
            if adb_launch_complete
              UI.message("Wait for ADB boot completed with success".yellow)

              if (params[:AVD_wait_for_bootcomplete] || params[:AVD_wait_for_boot_completed] || params[:AVD_wait_for_bootanim])
                message = "Performing wait for params: "
                
                if params[:AVD_wait_for_bootcomplete]
                  message += "'dev.bootcomplete', "
                end
               
                if params[:AVD_wait_for_boot_completed]
                  message += "'sys.boot_completed', "
                end
               
                if params[:AVD_wait_for_bootanim]
                  message += "'init.svc.bootanim', "
                end
               
                message = message[0...-2] + "."
                UI.message(message.yellow)

                param_launch_complete = wait_for_emulator_boot_by_params(params, adb_controller, avd_controllers, avd_schemes, "#{params[:AVD_param_launch_timeout]}")
              else
                UI.message("Wait for AVD launch params was turned off. Skipping...".yellow)
                param_launch_complete = true
              end
            else 
              UI.message("Wait for ADB boot failed".yellow)
            end

            all_avd_launched = adb_launch_complete && param_launch_complete

            # Deciding if AVD launch should be restarted
            devices_output = Action.sh(adb_controller.command_get_devices)

            devices = ""
            devices_output.each_line do |line|
              if line.include?("emulator-")
                devices += line.sub(/\t/, " ")  
              end
            end
            
            if all_avd_launched
              UI.message("AVDs Booted!".green)
              if params[:logcat]
                for i in 0...avd_schemes.length
                  device = ["emulator-", avd_schemes[i].launch_avd_port].join('')
                  cmd = [adb_controller.adb_path, '-s', device, 'logcat -c'].join(' ')
                  Action.sh(cmd) unless devices.match(device).nil?
                end
              end
            else
              for i in 0...avd_schemes.length
                if params[:verbose] 
                  # Display AVD output
                  if (File.exists?(avd_controllers[i].output_file.path))
                    UI.message(["Displaying log for AVD:", avd_schemes[i].avd_name].join(" ").red)
                    UI.message(avd_controllers[i].output_file.read.blue)
                  end
                end
                
                # Killing devices
                unless devices.match(["emulator-", avd_schemes[i].launch_avd_port].join("")).nil?
                  Action.sh(avd_controllers[i].command_kill_device)
                end
              end
            end
          end

          # Launching tests
          shell_task = "#{params[:shell_task]}" unless params[:shell_task].nil?
          gradle_task = "#{params[:gradle_task]}" unless params[:gradle_task].nil?

          UI.message("Starting tests".green)
          begin
            unless shell_task.nil?
              UI.message("Using shell task.".green)
              Action.sh(shell_task)
            end

            unless gradle_task.nil?
              gradle = Helper::GradleHelper.new(gradle_path: Dir["./gradlew"].last)

              UI.message("Using gradle task.".green)
              gradle.trigger(task: params[:gradle_task], flags: params[:gradle_flags], serial: nil)
            end
          ensure 
            # Clean up
            for i in 0...avd_schemes.length
              # Kill all emulators
              device = ["emulator-", avd_schemes[i].launch_avd_port].join("")
              unless devices.match(device).nil?
                if params[:logcat]
                  file = [device, '.log'].join('')
                  cmd = [adb_controller.adb_path, '-s', device, 'logcat -d >', file].join(' ')
                  Action.sh(cmd)
                end
                Action.sh(avd_controllers[i].command_kill_device)
              end

              if params[:verbose]
                # Display AVD output
                if (File.exists?(avd_controllers[i].output_file.path))
                  UI.message("Displaying log from AVD to console:".green)
                  UI.message(avd_controllers[i].output_file.read.blue)

                  UI.message("Removing temp file.".green)
                  avd_controllers[i].output_file.close
                  avd_controllers[i].output_file.unlink
                end
              end

              # Delete AVDs
              if params[:AVD_clean_after]
                UI.message("AVD_clean_after param set to true. Deleting AVDs.".green)
                Action.sh(avd_controllers[i].command_delete_avd)
              else
                UI.message("AVD_clean_after param set to false. Created AVDs won't be deleted.".green)
              end
            end
          end
        end

        def self.wait_for_emulator_boot_by_adb(adb_controller, avd_schemes, timeout)
          timeoutInSeconds= timeout.to_i
          interval = 1000 * 10
          startTime = Time.now
          lastCheckTime = Time.now
          launch_status_hash = Hash.new
          device_visibility_hash = Hash.new

          for i in 0...avd_schemes.length
            device_name = ["emulator-", avd_schemes[i].launch_avd_port].join("")
            launch_status_hash.store(device_name, false)
            device_visibility_hash.store(device_name, false)
          end

          launch_status = false
          loop do
            currentTime = Time.now
            if ((currentTime - lastCheckTime) * 1000) > interval 
              lastCheckTime = currentTime
              devices_output = Action.sh(adb_controller.command_get_devices)

              devices = ""
              devices_output.each_line do |line|
                if line.include?("emulator-")
                  devices += line.sub(/\t/, " ")  
                end
              end

              # Check if device is visible
              all_devices_visible = true
              device_visibility_hash.each do |name, is_visible|
                unless (devices.match(name).nil? || is_visible)
                  device_visibility_hash[name] = true
                end
                  all_devices_visible = false unless is_visible
              end

              # Check if device is booted
              all_devices_booted = true
              launch_status_hash.each do |name, is_booted|
                unless (devices.match(name + " device").nil? || is_booted)
                  launch_status_hash[name] = true
                end
                all_devices_booted = false unless launch_status_hash[name]
              end

              # Quit if timeout reached
              if ((currentTime - startTime) >= timeoutInSeconds) 
                UI.message(["AVD ADB loading took more than ", timeout, ". Attempting to re-launch."].join("").red)
                launch_status = false
                break
              end

              # Quit if all devices booted
              if (all_devices_booted && all_devices_visible)
                launch_status = true
                break
              end
            end
          end
          return launch_status
        end

        def self.wait_for_emulator_boot_by_params(params, adb_controller, avd_controllers, avd_schemes, timeout)
          timeout_in_seconds= timeout.to_i
          interval = 1000 * 10
          all_params_launched = false
          start_time = last_scan_ended = Time.now
          device_boot_statuses = Hash.new

          loop do
            current_time = Time.now

            # Performing single scan over each device
            if (((current_time - last_scan_ended) * 1000) >= interval || start_time == last_scan_ended)
              for i in 0...avd_schemes.length
                avd_schema = avd_schemes[i]
                avd_controller = avd_controllers[i]
                avd_param_boot_hash = Hash.new
                avd_param_status_hash = Hash.new
                avd_booted = false
                
                # Retreiving device parameters according to config
                if params[:AVD_wait_for_bootcomplete]
                  dev_bootcomplete, _stdeerr, _status = Open3.capture3([avd_controller.command_get_property, "dev.bootcomplete"].join(" "))
                  avd_param_boot_hash.store("dev.bootcomplete", dev_bootcomplete.strip.eql?("1"))
                  avd_param_status_hash.store("dev.bootcomplete", dev_bootcomplete)
                end

                if params[:AVD_wait_for_boot_completed] 
                   sys_boot_completed, _stdeerr, _status = Open3.capture3([avd_controller.command_get_property, "sys.boot_completed"].join(" "))
                   avd_param_boot_hash.store("sys.boot_completed", sys_boot_completed.strip.eql?("1"))
                   avd_param_status_hash.store("sys.boot_completed", sys_boot_completed)
                end

                if params[:AVD_wait_for_bootanim]
                   bootanim, _stdeerr, _status = Open3.capture3([avd_controller.command_get_property, "init.svc.bootanim"].join(" ")) 
                   avd_param_boot_hash.store("init.svc.bootanim", bootanim.strip.eql?("stopped"))
                   avd_param_status_hash.store("init.svc.bootanim", bootanim)
                end
                
                # Checking for param statuses
                avd_param_boot_hash.each do |name, is_booted|
                  if !is_booted
                    break
                  end
                  avd_booted = true
                end
                device_boot_statuses.store(avd_schema.avd_name, avd_booted)

                # Plotting current wait results
                device_log = "Device 'emulator-" + avd_schemes[i].launch_avd_port.to_s + "' launch status:"
                UI.message(device_log.magenta)
                avd_param_boot_hash.each do |name, is_booted|
                  device_log = "'" + name + "' - '" + avd_param_status_hash[name].strip + "' (launched: " + is_booted.to_s + ")"
                  UI.message(device_log.magenta)
                end
              end
              last_scan_ended = Time.now
            end
         
            # Checking if wait doesn't last too long
            if (current_time - start_time) >= timeout_in_seconds
              UI.message(["AVD param loading took more than ", timeout, ". Attempting to re-launch."].join("").red)
              all_params_launched = false
              break
            end

            # Finishing wait with success if all params are loaded for every device
            device_boot_statuses.each do |name, is_booted|
              if !is_booted
                break
              end
              all_params_launched = true
            end
            if all_params_launched 
              break
            end
          end 
          return all_params_launched
        end
       
        def self.available_options
        [
          #paths
          FastlaneCore::ConfigItem.new(key: :AVD_path,
                                       env_name: "AVD_PATH",
                                       description: "The path to your android AVD directory (root). ANDROID_SDK_HOME by default",
                                       default_value: (ENV['ANDROID_SDK_HOME'].nil? or ENV['ANDROID_SDK_HOME'].eql?("")) ? "~/.android/avd" : ENV['ANDROID_SDK_HOME'],
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :AVD_setup_path,
                                       env_name: "AVD_SETUP_PATH",
                                       description: "Location to AVD_setup.json file which contains info about how many AVD should be launched and their configs",
                                       is_string: true,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :SDK_path,
                                       env_name: "SDK_PATH",
                                       description: "The path to your android sdk directory (root). ANDROID_HOME by default",
                                       default_value: ENV['ANDROID_HOME'],
                                       is_string: true,
                                       optional: true),


          #launch config params
          FastlaneCore::ConfigItem.new(key: :AVD_param_launch_timeout,
                                       env_name: "AVD_PARAM_LAUNCH_TIMEOUT",
                                       description: "Timeout in seconds. Even though ADB might find all devices you still might want to wait for animations to finish and system to boot. Default 60 seconds",
                                       default_value: 60,
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :AVD_adb_launch_timeout,
                                       env_name: "AVD_ADB_LAUNCH_TIMEOUT",
                                       description: "Timeout in seconds. Wait until ADB finds all devices specified in config and sets their value to 'device'. Default 240 seconds",
                                       default_value: 240,
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :AVD_recreate_new,
                                       env_name: "AVD_RECREATE_NEW",
                                       description: "Allow to decide if AVDs from AVD_setup.json (in case they already exist) should be deleted and created from scratch",
                                       default_value: true,
                                       is_string: false,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :AVD_clean_after,
                                       env_name: "AVD_CLEAN_AFTER",
                                       description: "Allow to decide if AVDs should be deleted from PC after test session ends",
                                       default_value: true,
                                       is_string: false,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :ADB_restart,
                                       env_name: "ADB_RESTART",
                                       description: "Allows to switch adb restarting on/off",
                                       default_value: true,
                                       is_string: false,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :AVD_wait_for_bootcomplete,
                                       env_name: "AVD_BOOTCOMPLETE_WAIT",
                                       description: "Allows to switch wait for 'dev.bootcomplete' AVD launch param on/off",
                                       default_value: true,
                                       is_string: false,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :AVD_wait_for_boot_completed,
                                       env_name: "AVD_BOOT_COMPLETED_WAIT",
                                       description: "Allows to switch wait for 'sys.boot_completed' AVD launch param on/off",
                                       default_value: true,
                                       is_string: false,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :AVD_wait_for_bootanim,
                                       env_name: "ABD_BOOTANIM_WAIT",
                                       description: "Allows to switch wait for 'init.svc.bootanim' AVD launch param on/off",
                                       default_value: true,
                                       is_string: false,
                                       optional: true),
          
          #launch commands
          FastlaneCore::ConfigItem.new(key: :shell_task,
                                       env_name: "SHELL_TASK",
                                       description: "The shell command you want to execute",
                                       conflicting_options: [:gradle_task], 
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :gradle_task,
                                       env_name: "GRADLE_TASK",
                                       description: "The gradle task you want to execute",
                                       conflicting_options: [:shell_command],
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :gradle_flags,
                                       env_name: "GRADLE_FLAGS",
                                       description: "All parameter flags you want to pass to the gradle command, e.g. `--exitcode --xml file.xml`",
                                       conflicting_options: [:shell_command],
                                       optional: true,
                                       is_string: true),

          #mode
          FastlaneCore::ConfigItem.new(key: :verbose,
                                       env_name: "AVD_VERBOSE",
                                       description: "Allows to turn on/off mode verbose which displays output of AVDs",
                                       default_value: false,
                                       is_string: false,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :logcat,
                                       env_name: "ADB_LOGCAT",
                                       description: "Allows to turn logcat on/off so you can debug crashes and such",
                                       default_value: false,
                                       is_string: false,
                                       optional: true),
        ]
        end

        def self.description
            "Starts AVD, based on AVD_setup.json file, before test launch and kills it after testing is done."
        end

        def self.authors
            ["F1sherKK"]
        end

        def self.is_supported?(platform)
            platform == :android
        end
      end
  end
end
