module Fastlane
  module Provider

    class AVD_scheme
      attr_accessor :avd_name, :create_avd_package, :create_avd_device, :create_avd_tag, :create_avd_abi, :create_avd_hardware_config_filepath, :create_avd_additional_options, 
                    :launch_avd_port, :launch_avd_launch_binary_name, :launch_avd_additional_options, :launch_avd_snapshot_filepath
    end

    class AvdSchemeProvider
      
        def self.get_avd_schemes(params)
        
          # Read JSON into string variable
          avd_setup_json = read_avd_setup(params)
          if avd_setup_json.nil? 
            throw_error("Unable to read AVD_setup.json. Check JSON file structure or file path.")
          end

          # Read JSON into Hash
          avd_setup = JSON.parse(avd_setup_json)
          avd_hash_list = avd_setup['avd_list']

          # Create AVD_scheme objects and fill them with data
          avd_scheme_list = []
          for i in 0...avd_hash_list.length
            avd_hash = avd_hash_list[i]

            avd_scheme = AVD_scheme.new
            avd_scheme.avd_name = avd_hash['avd_name']

            avd_scheme.create_avd_package = avd_hash['create_avd_package']
            avd_scheme.create_avd_device = avd_hash['create_avd_device']
            avd_scheme.create_avd_tag = avd_hash['create_avd_tag']
            avd_scheme.create_avd_abi = avd_hash['create_avd_abi']
            avd_scheme.create_avd_hardware_config_filepath = avd_hash['create_avd_hardware_config_filepath']

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
          
          # Prepare list of open ports for AVD_schemes without ports set in JSON
          avaliable_ports = get_unused_even_tcp_ports(5556, 5586, avd_scheme_list)

          # Fill empty AVD_schemes with open ports
          for i in 0...avd_scheme_list.length
            avd_scheme = avd_scheme_list[i]
            if avd_scheme.launch_avd_port.eql? ""
              avd_scheme.launch_avd_port = avaliable_ports[0]
              avaliable_ports.delete(avaliable_ports[0])
            end
          end

          return avd_scheme_list
        end 

        def self.get_unused_even_tcp_ports(min_port, max_port, avd_scheme_list) 
          if min_port % 2 != 0
            min_port += 1
          end

          if max_port % 2 != 0
            max_port += 1
          end

          avaliable_ports = []
          reserved_ports = []

          # Gather ports requested in JSON config
          for i in 0...avd_scheme_list.length
            avd_scheme = avd_scheme_list[i]
            unless avd_scheme.launch_avd_port.eql? ""
              reserved_ports << avd_scheme.launch_avd_port
            end
          end

          # Find next open port which wasn't reserved in JSON config
          port = min_port
          for i in 0...avd_scheme_list.length
            
            while port < max_port  do
              if !system("lsof -i:#{port}", out: '/dev/null')

                is_port_reserved = false
                for j in 0...reserved_ports.length 
                  if reserved_ports[j].eql?(port.to_s)
                    is_port_reserved = true
                    break
                  end
                end

                if is_port_reserved
                  port = port + 2
                  break
                end

                avaliable_ports << port
                port = port + 2
                break
              else 
                port = port + 2
              end
            end
          end

          return avaliable_ports
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
          if avd_scheme.create_avd_package.nil? 
              errors.push("create_avd_package not found")
          end
          if avd_scheme.create_avd_device.nil? 
              errors.push("create_avd_device not found")
          end
          if avd_scheme.create_avd_tag.nil? 
              errors.push("create_avd_tag not found")
          end
          if avd_scheme.create_avd_abi.nil? 
              errors.push("create_avd_abi not found")
          end
          if avd_scheme.create_avd_hardware_config_filepath.nil? 
              errors.push("create_avd_hardware_config_filepath not found")
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