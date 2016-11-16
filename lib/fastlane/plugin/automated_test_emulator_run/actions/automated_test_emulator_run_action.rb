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
          for i in 0..(avd_schemes.length - 1)
            avd_scheme = avd_schemes[i]
            avd_controller = Factory::AvdControllerFactory.get_avd_controller(params, avd_scheme)
            avd_controllers << avd_controller
          end

          all_avd_launched = false

          while(!all_avd_launched)

            # Preparation
            UI.message("Configuring environment in order to launch emulators: ".yellow)
           
            UI.message("Getting avaliable AVDs".yellow)
            devices = Action.sh(adb_controller.command_get_avds)
           
            for i in 0..(avd_schemes.length - 1)
              avd_scheme = avd_schemes[i]
              avd_controller = avd_controllers[i]
              
              # Delete existing AVDs
              if !devices.match(avd_scheme.avd_name).nil?
                UI.message(["Deleting existing AVD with name:", avd_scheme.avd_name].join(" ").yellow)
                Action.sh(avd_controller.command_delete_avd)
              end

              # Re-create deleted AVDs
              UI.message("Creating new AVD".yellow)
              Action.sh(avd_controller.command_create_avd)
            end

            # Restart ADB
            UI.message("Restarting adb".yellow)
            Action.sh(adb_controller.command_stop)
            Action.sh(adb_controller.command_start)

            # Applying custom configs (it's not done directly after create because 'cat' operation seems to fail overwrite)
            for i in 0..(avd_schemes.length - 1)
              avd_scheme = avd_schemes[i]
              avd_controller = avd_controllers[i]
            
              UI.message(["Attemting to apply custom config to ", avd_scheme.avd_name].join("").yellow)
              if avd_controller.command_apply_config_avd.eql? "" 
                 UI.message(["No config file found for AVD '", avd_scheme.avd_name, "'. AVD won't have config.ini applied."].join("").yellow)
              else
                UI.message(["Config file found! Applying custom config to: ", avd_scheme.avd_name].join("").yellow)
                Action.sh(avd_controller.command_apply_config_avd)
              end
            end

            # Launching AVDs
            UI.message("Launching all AVDs at the same time".yellow)
            for i in 0..(avd_schemes.length - 1)
              avd_scheme = avd_schemes[i]
              avd_controller = avd_controllers[i]

              Action.sh(avd_controller.command_start_avd)
            end

            # Wait for AVDs finish booting
            UI.message("Waiting for AVDs to finish booting".yellow)
            boot_status = []
            for i in 0..(avd_schemes.length - 1)
              boot_status << false
            end

            UI.message("Performing wait for params: dev.bootcomplete, sys.boot_completed, init.svc.bootanim".yellow)
            for i in 0..(avd_schemes.length - 1)
              avd_controller = avd_controllers[i]
              status = wait_for_emulator_boot(adb_controller, avd_controller)
              
              if (!status)
                all_avd_launched = false
                break
              end
              all_avd_launched = true
            end

            # Deciding if AVD launch should be restarted
            devices = Action.sh(adb_controller.command_get_devices)
            if all_avd_launched
              UI.message("AVDs Booted!".green)
            else
              for i in 0..(avd_schemes.length - 1)
                avd_scheme = avd_schemes[i]
                avd_controller = avd_controllers[i]

                # Kill all emulators
                if !devices.match(["emulator-", avd_scheme.launch_avd_port].join("")).nil?
                  Action.sh(avd_controller.command_kill_device)
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
              UI.message("Using shell task".green)
              Action.sh(shell_task)
            end

            unless gradle_task.nil?
              UI.message("Using gradle task".green)
              gradle.trigger(task: params[:gradle_task], flags: params[:gradle_flags], serial: nil)
            end
          ensure 
            # Clean up
            for i in 0..(avd_schemes.length - 1)
              avd_scheme = avd_schemes[i]
              avd_controller = avd_controllers[i]

              # Kill all emulators
              if !devices.match(["emulator-", avd_scheme.launch_avd_port].join("")).nil?
                Action.sh(avd_controller.command_kill_device)
              end

              # Delete AVDs
              Action.sh(avd_controller.command_delete_avd)
            end
          end

        end

        def self.wait_for_emulator_boot(adb_controller, avd_controller)
            timeoutInSeconds= 240.0
            startTime = Time.now

            launch_status = false
            loop do
              dev_bootcomplete, _stdeerr, _status = Open3.capture3([avd_controller.command_get_property, "dev.bootcomplete"].join(" ")) 
              sys_boot_completed, _stdeerr, _status = Open3.capture3([avd_controller.command_get_property, "sys.boot_completed"].join(" ")) 
              bootanim, _stdeerr, _status = Open3.capture3([avd_controller.command_get_property, "init.svc.bootanim"].join(" ")) 
              currentTime = Time.now

              if (currentTime - startTime) >= timeoutInSeconds
                UI.message("AVD loading took more than 4 minutes. Restarting launch".red)
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