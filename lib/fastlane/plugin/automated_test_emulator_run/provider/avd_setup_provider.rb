module Fastlane
  module Provider

    class AVD_scheme
      attr_accessor :avd_name, :create_avd_target, :create_avd_abi, :create_avd_hardware_config_filepath, :create_avd_additional_options, 
                    :launch_avd_port, :launch_avd_launch_binary_name, :launch_avd_additional_options, :launch_avd_snapshot_filepath
    end

    class AvdSchemeProvider
      
        def self.get_avd_schemes(params)
          avd_setup_json = read_avd_setup(params)
          if avd_setup_json.nil? 
            throw_error("Unable to read AVD_setup.json. Check JSON file structure or file path.")
          end

          avd_setup = JSON.parse(avd_setup_json)
          avd_hash_list = avd_setup['avd_list']

          avd_scheme_list = []

          for i in 0..(avd_hash_list.length - 1)
            avd_hash = avd_hash_list[i]

            avd_scheme = AVD_scheme.new
            avd_scheme.avd_name = avd_hash['avd_name']
            avd_scheme.create_avd_target = avd_hash['create_avd_target']
            avd_scheme.create_avd_abi = avd_hash['create_avd_abi']
            avd_scheme.create_avd_hardware_config_filepath = avd_hash['create_avd_hardware_config_filepath']
            avd_scheme.create_avd_additional_options = avd_hash['create_avd_additional_options']
            avd_scheme.launch_avd_port = avd_hash['launch_avd_port']
            avd_scheme.launch_avd_launch_binary_name = avd_hash['launch_avd_launch_binary_name']
            avd_scheme.launch_avd_additional_options = avd_hash['launch_avd_additional_options']
            avd_scheme.launch_avd_snapshot_filepath = avd_hash['launch_avd_snapshot_filepath']

            errors = check_avd_fields(avd_scheme)
            unless errors.empty?
              error_log = "Error! Fields not found in JSON: \n"
              errors.each { |error| error_log += error + "\n" }
              throw_error(error_log)
            end

            avd_scheme_list << avd_scheme
          end
  
          return avd_scheme_list
        end 

        def self.read_avd_setup(params)
          if File.exists?(File.expand_path("#{params[:AVD_setup_path]}"))
            file = File.open(File.expand_path("#{params[:AVD_setup_path]}"), "rb")
            json = file.read
            file.close
            return json
          else
            return nil
          end
        end

        def self.check_avd_fields(avd_scheme)
          errors = []
            
          if avd_scheme.avd_name.nil? 
              errors.push("avd_name not found")
          end
          if avd_scheme.create_avd_target.nil? 
              errors.push("create_avd_target not found")
          end
          if avd_scheme.create_avd_abi.nil? 
              errors.push("create_avd_abi not found")
          end
          if avd_scheme.create_avd_hardware_config_filepath.nil? 
              errors.push("create_avd_hardware_config_filepath not found")
          end
          if avd_scheme.create_avd_additional_options.nil? 
              errors.push("create_avd_additional_options not found")
          end
          if avd_scheme.launch_avd_snapshot_filepath.nil? 
              errors.push("launch_avd_snapshot_filepath not found")
          end
          if avd_scheme.launch_avd_launch_binary_name.nil?
            errors.push("launch_avd_launch_binary_name not found")
          end
          if avd_scheme.launch_avd_port.nil? 
              errors.push("launch_avd_port not found")
          end
          if avd_scheme.launch_avd_additional_options.nil? 
              errors.push("launch_avd_additional_options not found")
          end

          return errors
        end

        def self.throw_error(message) 
          UI.message("Error: ".red + message.red)
          raise Exception, "Lane was stopped by plugin"
        end
    end
  end
end