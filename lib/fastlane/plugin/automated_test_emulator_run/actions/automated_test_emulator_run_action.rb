require 'open3'
require 'tempfile'

module Fastlane
  module Actions
     module SharedValues
     end

    class AutomatedTestEmulatorRunAction < Action

      def self.run(params)
        gradle = Helper::GradleHelper.new(gradle_path: Dir["./gradlew"].last)

        UI.message("The automated_test_emulator_run plugin is working!")

        # Find unused port
        port = getUnusedTcpPort
        if params[:avd_port].nil? 
          port = getUnusedTcpPort
          UI.message(["Open port found", port].join(" ").yellow)
        else
          port = "#{params[:avd_port]}"
          UI.message(["Port set by user to:", port].join(" ").yellow)
        end

        # Set up params 
        UI.message("Preparing parameters...".yellow)

          # AVD general params
          avdRoot = "#{params[:avd_path]}"
          sdkRoot = "#{params[:sdk_path]}"
          avd_name = "--name \"#{params[:avd_name]}\""

          # AVD create params
          target_id = "--target \"#{params[:target_id]}\""
          avd_abi = "--abi #{params[:avd_abi]}" unless params[:avd_abi].nil?
          avd_tag = "--tag #{params[:avd_tag]}" unless params[:avd_tag].nil?
          avd_create_options = params[:avd_create_options] unless params[:avd_create_options].nil?

          # AVD start params
          emulator_binary = "#{params[:emulator_binary]}"
          avd_initdata = "-wipe-data -initdata #{params[:initdata_snapshot_path]}" unless params[:initdata_snapshot_path].nil?
          avd_port = ["-port", port].join(" ")
          avd_start_options = params[:avd_start_options] unless params[:avd_start_options].nil?

        # Set up commands
        UI.message("Setting up run commands".yellow)
        create_avd_command = ["echo \"no\" |", sdkRoot + "/tools/android", "create avd", avd_name, target_id, avd_abi, avd_tag, avd_create_options].join(" ")
        get_devices_command = sdkRoot + "/tools/android list avd".chomp
        start_avd_command = [sdkRoot + "/tools/" + emulator_binary, avd_port, "-avd #{params[:avd_name]}", avd_initdata, avd_start_options, "&>/dev/null &"].join(" ")
        shell_command = "#{params[:shell_command]}" unless params[:shell_command].nil?
        gradle_task = "#{params[:gradle_task]}" unless params[:gradle_task].nil?

        # Recreating AVD
        UI.message("Creating AVD...".yellow)
        createEmulator(get_devices_command, create_avd_command, params, sdkRoot)
        configEmulator(params, avdRoot)

        # Starting AVD
        UI.message("Starting AVD....".yellow)
        launchEmulator(start_avd_command, get_devices_command, create_avd_command, sdkRoot, port, params)
      
        UI.message("Starting tests".green)
        begin
          unless shell_command.nil?
            UI.message("Using shell command".green)
            Action.sh(shell_command)
          end

          unless gradle_task.nil?
            UI.message("Using gradle task".green)
            gradle.trigger(task: params[:gradle_task], flags: params[:gradle_flags], serial: nil)
          end
        end

        waitFor_emulatorStop(sdkRoot, port, params)
      end

      def self.getUnusedTcpPort 
        min_port = 5556
        max_port = 5586

        port = min_port
        while port < max_port  do
           unless system(["lsof -i:", port].join(""), out: '/dev/null')
              break
           end
           port +=1
        end
        return port
      end

      def self.createEmulator(get_devices_command, create_avd_command, params, sdkRoot)
        UI.message("Getting avaliable devices".yellow)
        devices = Action.sh(get_devices_command)

        unless devices.match(/#{params[:avd_name]}/).nil?
           UI.message("Deleting existing AVD to create fresh one".yellow)
           Action.sh(sdkRoot + "/tools/android delete avd -n #{params[:avd_name]}")
        end

        Action.sh(create_avd_command)
      end

      def self.configEmulator(params, avdRoot)
        avd_name = params[:avd_name]
        avd_hw_config = params[:avd_hw_config] unless
            unless params[:avd_hw_config].nil?
              UI.message("Configuring AVD...".yellow)
              Action.sh("cat #{params[:avd_hw_config]} > " + avdRoot + "/#{params[:avd_name]}.avd/config.ini")
            end
      end

      def self.launchEmulator(start_avd_command, get_devices_command, create_avd_command, sdkRoot, port, params)
        restart_adb(sdkRoot)
        Action.sh(start_avd_command)
        waitFor_emulatorBoot(start_avd_command, get_devices_command, create_avd_command, sdkRoot, port, params)
      end

      def self.waitFor_emulatorBoot(start_avd_command, get_devices_command, create_avd_command, sdkRoot, port, params)
        UI.message("Waiting for emulator to finish booting.....".yellow)
        startParams = "#{params[:avd_start_options]}"

        if startParams.include? "-no-window" 
          Action.sh(sdkRoot + "/platform-tools/adb wait-for-device")
          Action.sh(sdkRoot + "/platform-tools/adb devices")
          return true
        else
          timeoutInSeconds= 150.0
          startTime = Time.now
          loop do
            dev_bootcomplete, _stdeerr, _status = Open3.capture3(sdkRoot + ["/platform-tools/adb -s emulator-", port].join("") + " shell getprop dev.bootcomplete")
            sys_boot_completed, _stdeerr, _status = Open3.capture3(sdkRoot + ["/platform-tools/adb -s emulator-", port].join("") + " shell getprop sys.boot_completed")
            bootanim, _stdeerr, _status = Open3.capture3(sdkRoot + ["/platform-tools/adb -s emulator-", port].join("") + " shell getprop init.svc.bootanim")
            currentTime = Time.now

            if (currentTime - startTime) >= timeoutInSeconds
              UI.message("Emulator loading took more than 2 minutes 30 seconds. Restarting emulator launch until.".yellow)
              adb_devices_result = Action.sh(sdkRoot + "/platform-tools/adb devices")
              if adb_devices_result.include? "offline"
                kill_emulator(sdkRoot, port, params)

                delayInSeconds = 20.0
                sleep(delayInSeconds)

                delete_emulator(sdkRoot, port, params)

                createEmulator(get_devices_command, create_avd_command, params, sdkRoot)

                launchEmulator(start_avd_command, get_devices_command, create_avd_command, sdkRoot, port, params)
                break
              end
              return false
            end

            if (dev_bootcomplete.strip == "1" && sys_boot_completed.strip == "1" && bootanim.strip == "stopped")
              UI.message("Emulator Booted!".green)
              return true
            end
          end
        end
      end

      def self.restart_adb(sdkRoot)
          UI.message("Restarting adb..".green)
          Action.sh(sdkRoot + "/platform-tools/adb kill-server")
          Action.sh(sdkRoot + "/platform-tools/adb start-server")
      end

      def self.kill_emulator(sdkRoot, port, params)
          UI.message("Shutting down emulator...".green)
          Action.sh(sdkRoot + "/platform-tools/adb -s " + ["emulator-", port].join("") + " emu kill &>/dev/null")
      end

      def self.delete_emulator(sdkRoot, port, params) 
          UI.message("Deleting emulator....".green)
          Action.sh(sdkRoot + "/tools/android delete avd -n #{params[:avd_name]}")
      end

      def self.waitFor_emulatorStop(sdkRoot, port, params)
          kill_emulator(sdkRoot, port, params)

          delayInSeconds = 20.0
          sleep(delayInSeconds)

          delete_emulator(sdkRoot, port, params)
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :avd_name,
                                     env_name: "AVD_NAME",
                                     description: "Name of the avd to be created",
                                     is_string: true,
                                     optional: false),
          FastlaneCore::ConfigItem.new(key: :target_id,
                                     env_name: "TARGET_ID",
                                     description: "Target id of the avd to be created, get list of installed target by running command 'android list targets'",
                                     is_string: true,
                                     optional: false),
          FastlaneCore::ConfigItem.new(key: :avd_create_options,
                                     env_name: "AVD_CREATE_OPTIONS",
                                     description: "Other avd options, used during avd creation, in the form of a <option>=<value> list, i.e \"--scale 96dpi --dpi-device 160\"",
                                     is_string: true,
                                     optional: true),
          FastlaneCore::ConfigItem.new(key: :avd_abi,
                                     env_name: "AVD_ABI",
                                     description: "The ABI to use for the AVD. The default is to auto-select the ABI if the platform has only one ABI for its system images",
                                     is_string: true,
                                     optional: true),
          FastlaneCore::ConfigItem.new(key: :avd_tag,
                                     env_name: "AVD_TAG",
                                     description: "The sys-img tag to use for the AVD. The default is to auto-select if the platform has only one tag for its system images",
                                     is_string: true,
                                     optional: true),
          FastlaneCore::ConfigItem.new(key: :avd_hw_config,
                                       env_name: "AVD_HW_CONFIG",
                                       description: "The path of the AVD hardware configuration (config.ini)",
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :avd_path,
                                       env_name: "AVD_PATH",
                                       description: "The path to your android AVD directory (root). HOME/.android/avd by default",
                                       is_string: true,
                                       default_value: ENV['HOME'] + '/.android/avd',
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :sdk_path,
                                     env_name: "SDK_PATH",
                                     description: "The path to your android sdk directory (root). ANDROID_HOME by default",
                                     is_string: true,
                                     default_value: ENV['ANDROID_HOME'],
                                     optional: true),

          FastlaneCore::ConfigItem.new(key: :shell_command,
                                     env_name: "SHELL_COMMAND",
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
           
          FastlaneCore::ConfigItem.new(key: :emulator_binary,
                                     env_name: "EMULATOR_BINARY",
                                     description: "Emulator binary file you would like to use in order to start emulator",
                                     is_string: true,
                                     default_value: "emulator",
                                     optional: true),
          FastlaneCore::ConfigItem.new(key: :avd_port,
                                     env_name: "AVD_PORT",
                                     description: "Possible to specify port on which emulator should run",
                                     is_string: true,
                                     optional: true),
          FastlaneCore::ConfigItem.new(key: :avd_start_options,
                                     env_name: "AVD_START_OPTIONS",
                                     description: "Additonal run parameters e.g. gpu, audio, boot animation",
                                     is_string: true,
                                     optional: true),
          FastlaneCore::ConfigItem.new(key: :initdata_snapshot_path,
                                     env_name: "INIT_DATA_PATH",
                                     description: "The path to userdata-qemu which will be used to initialize AVD status",
                                     is_string: true,
                                     optional: true),
        ]
      end

      def self.description
        "Starts single emulator before running tests."
      end

      def self.authors
        ["joshrlesch, modified by F1sherKK"]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end