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

        # Create output file
        file = Tempfile.new('emulator_output')
        UI.message(["Created temp file for emulator output", file.path].join(" ").yellow)

        # Find unused port
        port = getUnusedTcpPort
        UI.message(["Open port found", port].join(" ").yellow)

        # Set up params 
        UI.message("Preparing parameters...".yellow)
        avd_name = "--name \"#{params[:avd_name]}\""
        target_id = "--target \"#{params[:target_id]}\""
        avd_abi = "--abi #{params[:avd_abi]}" unless params[:avd_abi].nil?
        avd_tag = "--tag #{params[:avd_tag]}" unless params[:avd_tag].nil?
        avd_create_options = params[:avd_create_options] unless params[:avd_create_options].nil?
        avd_initdata = "-wipe-data -initdata #{params[:initdata_snapshot_path]}" unless params[:initdata_snapshot_path].nil?
        avd_port = ["-port", port].join(" ")
        sdkRoot = getSdkRoot(params)

        # Set up commands
        UI.message("Setting up run commands".yellow)
        create_avd_command = [sdkRoot + "/tools/android", "create avd", avd_name, target_id, avd_abi, avd_tag, avd_create_options].join(" ")
        get_devices_command = sdkRoot + "/tools/android list avd".chomp
        start_avd_command = [sdkRoot + "/tools/emulator", avd_port, "-avd #{params[:avd_name]}", avd_initdata, "-gpu on -no-boot-anim &>#{file.path} &"].join(" ")
        shell_command = "#{params[:shell_command]}" unless params[:shell_command].nil?
        gradle_task = "#{params[:gradle_task]}" unless params[:gradle_task].nil?

        # Get Available Devices
        UI.message("Getting avaliable devices".yellow)
        devices = Action.sh(get_devices_command)

        # Delete avd if one already exists for clean state.
        unless devices.match(/#{params[:avd_name]}/).nil?
           UI.message("Deleting existing AVD to create fresh one".yellow)
           Action.sh(sdkRoot + "/tools/android delete avd -n #{params[:avd_name]}")
        end

        # Creating AVD
        UI.message("Creating AVD...".yellow)
        Action.sh(create_avd_command)

        # Starting AVD
        UI.message("Starting AVD....".yellow)
        begin
          Action.sh(start_avd_command)
          waitFor_emulatorBoot(sdkRoot, port)

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
          ensure 
            waitFor_emulatorStop(sdkRoot, port, params, file)
          end
        ensure
          file.close
          file.unlink
        end
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

      def self.getSdkRoot(params)
        dirs = "#{params[:sdk_path]}".split(':')
        sdkRoot = ""
        dirs.each do |dir|
          if dir.include? "sdk"
              sdkEndPos = dir.index("sdk") + "sdk".length
              sdkRoot = dir.slice(0, sdkEndPos)
              break
          end
        end
        return sdkRoot
      end

      def self.waitFor_emulatorBoot(sdkRoot, port)
        UI.message("Waiting for emulator to finish booting.....".yellow)
        loop do
          stdout, _stdeerr, _status = Open3.capture3(sdkRoot + ["/platform-tools/adb -s emulator-", port].join("") + " shell getprop sys.boot_completed")

          if stdout.strip == "1"
            break
          end
        end
        UI.message("Emulator Booted!".green)
      end

      def self.waitFor_emulatorStop(sdkRoot, port, params, file)
        adb = Helper::AdbHelper.new(adb_path: sdkRoot + "/platform-tools/adb")
        temp = File.open(file.path).read

        UI.message("Shutting down emulator...".green)
        adb.trigger(command: "emu kill", serial: "emulator-#{port}")

        UI.message("Deleting emulator....".green)
        Action.sh(sdkRoot + "/tools/android delete avd -n #{params[:avd_name]}")
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
          FastlaneCore::ConfigItem.new(key: :initdata_snapshot_path,
                                     env_name: "INIT_DATA_PATH",
                                     description: "The path to userdata-qemu which will be used to initialize AVD status",
                                     is_string: true,
                                     optional: true),
          FastlaneCore::ConfigItem.new(key: :sdk_path,
                                     env_name: "SDK_PATH",
                                     description: "The path to your android sdk directory (root)",
                                     is_string: true,
                                     default_value: ENV['PATH'],
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