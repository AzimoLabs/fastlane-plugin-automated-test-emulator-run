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
          end

          all_avd_launched = false

          while(!all_avd_launched)

            # Preparation
            UI.message("Configuring environment in order to launch emulators: ".yellow)
            UI.message("Getting avaliable AVDs".yellow)
            devices = Action.sh(adb_controller.command_get_avds)
           
            for i in 0...avd_schemes.length           
              unless devices.match(avd_schemes[i].avd_name).nil?
                UI.message(["AVD with name '", avd_schemes[i].avd_name, " 'currently exists."].join("").yellow)
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
            UI.message("Restarting adb".yellow)
            Action.sh(adb_controller.command_stop)
            Action.sh(adb_controller.command_start)

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
              Action.sh(avd_controllers[i].command_start_avd)
            end

            # Wait for AVDs finish booting
            UI.message("Waiting for AVDs to finish booting.".yellow)
            boot_status = []
            for i in 0...avd_schemes.length
              boot_status << false
            end

            UI.message("Performig wait for ADB boot".yellow)
            all_avd_launched = wait_for_emulator_boot_by_adb(adb_controller, avd_schemes, "#{params[:AVD_adb_launch_timeout]}")

            if all_avd_launched
              UI.message("Wait for ADB boot completed with success".yellow)
              UI.message("Performing wait for params: dev.bootcomplete, sys.boot_completed, init.svc.bootanim.".yellow)
              for i in 0...avd_schemes.length
                all_avd_launched = wait_for_emulator_boot_by_params(adb_controller, avd_controllers[i], "#{params[:AVD_param_launch_timeout]}")
                unless all_avd_launched 
                  break 
                end     
              end
            else 
              UI.message("Wait for ADB boot failed".yellow)
            end

            # Deciding if AVD launch should be restarted
            devices = Action.sh(adb_controller.command_get_devices)
            if all_avd_launched
              UI.message("AVDs Booted!".green)
            else
              for i in 0...avd_schemes.length
                unless devices.match(["emulator-", avd_schemes[i].launch_avd_port].join("")).nil?
                  Action.sh(avd_controllers[i].command_kill_device)
                end
              end
            end
          end

          # Launching tests
          gradle = Helper::GradleHelper.new(gradle_path: Dir["./gradlew"].last)

          shell_task = "#{params[:shell_task]}" unless params[:shell_task].nil?
          gradle_task = "#{params[:gradle_task]}" unless params[:gradle_task].nil?

          UI.message("Starting tests".green)
          begin
            unless shell_task.nil?
              UI.message("Using shell task.".green)
              Action.sh(shell_task)
            end

            unless gradle_task.nil?
              UI.message("Using gradle task.".green)
              gradle.trigger(task: params[:gradle_task], flags: params[:gradle_flags], serial: nil)
            end
          ensure 
            # Clean up
            for i in 0...avd_schemes.length
              # Kill all emulators
              unless devices.match(["emulator-", avd_schemes[i].launch_avd_port].join("")).nil?
                Action.sh(avd_controllers[i].command_kill_device)
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
          startTime = Time.now

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
            devices = Action.sh(adb_controller.command_get_devices)

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
              all_devices_booted = false unless is_booted
            end

            if ((currentTime - startTime) >= timeoutInSeconds) 
              UI.message(["AVD ADB loading took more than ", timeout, ". Attempting to re-launch."].join("").red)
              launch_status = false
              break
            end

            if (all_devices_booted && all_devices_visible)
              launch_status = true
              break
            end
            sleep(10)
          end
          return launch_status
        end

        def self.wait_for_emulator_boot_by_params(adb_controller, avd_controller, timeout)
            timeoutInSeconds= timeout.to_i
            startTime = Time.now

            launch_status = false
            loop do
              dev_bootcomplete, _stdeerr, _status = Open3.capture3([avd_controller.command_get_property, "dev.bootcomplete"].join(" ")) 
              sys_boot_completed, _stdeerr, _status = Open3.capture3([avd_controller.command_get_property, "sys.boot_completed"].join(" ")) 
              bootanim, _stdeerr, _status = Open3.capture3([avd_controller.command_get_property, "init.svc.bootanim"].join(" ")) 
              currentTime = Time.now

              if (currentTime - startTime) >= timeoutInSeconds
                UI.message(["AVD param loading took more than ", timeout, ". Attempting to re-launch."].join("").red)
                launch_status = false
                break
              end

              if (dev_bootcomplete.strip == "1" && sys_boot_completed.strip == "1" && bootanim.strip == "stopped")
                launch_status = true
                break
              end
            end
            return launch_status
        end
       
        def self.available_options
        [
          #paths
          FastlaneCore::ConfigItem.new(key: :AVD_path,
                                       env_name: "AVD_PATH",
                                       description: "The path to your android AVD directory (root). HOME/.android/avd by default",
                                       is_string: true,
                                       default_value: ENV['HOME'] + '/.android/avd',
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :AVD_setup_path,
                                       env_name: "AVD_SETUP_PATH",
                                       description: "Location to AVD_setup.json file which contains info about how many AVD should be launched and their configs",
                                       is_string: true,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :SDK_path,
                                       env_name: "SDK_PATH",
                                       description: "The path to your android sdk directory (root). ANDROID_HOME by default",
                                       is_string: true,
                                       default_value: ENV['ANDROID_HOME'],
                                       optional: true),


          #emulator re-launch config params
          FastlaneCore::ConfigItem.new(key: :AVD_param_launch_timeout,
                                       env_name: "AVD_PARAM_LAUNCH_TIMEOUT",
                                       description: "Timeout in seconds. Even though ADB might find all devices you still might want to wait for animations to finish and system to boot. Default 60 seconds",
                                       is_string: true,
                                       default_value: 60,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :AVD_adb_launch_timeout,
                                       env_name: "AVD_ADB_LAUNCH_TIMEOUT",
                                       description: "Timeout in seconds. Wait until ADB finds all devices specified in config and sets their value to 'device'. Default 240 seconds",
                                       is_string: true,
                                       default_value: 240,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :AVD_recreate_new,
                                       env_name: "AVD_RECREATE_NEW",
                                       description: "Allow to decide if AVDs from AVD_setup.json (in case they already exist) should be deleted and created from scratch",
                                       default_value: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :AVD_clean_after,
                                       env_name: "AVD_CLEAN_AFTER",
                                       description: "Allow to decide if AVDs should be deleted from PC after test session ends",
                                       default_value: true,
                                       optional: true),

          #launch commands
          FastlaneCore::ConfigItem.new(key: :shell_task,
                                       env_name: "SHELL_TASK",
                                       description: "The shell command you want to execute",
                                       is_string: true,
                                       conflicting_options: [:gradle_task], 
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :gradle_task,
                                       env_name: "GRADLE_TASK",
                                       description: "The gradle task you want to execute",
                                       is_string: true,
                                       conflicting_options: [:shell_command],
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :gradle_flags,
                                       env_name: "GRADLE_FLAGS",
                                       description: "All parameter flags you want to pass to the gradle command, e.g. `--exitcode --xml file.xml`",
                                       optional: true,
                                       conflicting_options: [:shell_command],
                                       is_string: true),
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