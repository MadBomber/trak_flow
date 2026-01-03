# frozen_string_literal: true

module TrakFlow
  class CLI < Thor
    # Config subcommands
    class ConfigCommands < Thor
      class_option :json, aliases: "-j", type: :boolean, default: false, desc: "Output in JSON format"

      XDG_CONFIG_PATH = File.expand_path("~/.config/trak_flow/trak_flow.yml").freeze
      PROJECT_CONFIG_PATH = ".trak_flow/config.yml"

      desc "show", "Show the current configuration file"
      def show
        active_path = find_active_config_path

        if active_path.nil?
          output({ error: "No config file found", paths: { xdg: XDG_CONFIG_PATH, project: PROJECT_CONFIG_PATH } }) do
            puts pastel.yellow("No configuration file found.")
            puts "Create one with: tf config reset"
            puts ""
            puts "Expected locations:"
            puts "  XDG:     #{XDG_CONFIG_PATH}"
            puts "  Project: #{File.expand_path(PROJECT_CONFIG_PATH)}"
          end
          return
        end

        config_content = File.read(active_path)

        if options[:json]
          yaml_data = YAML.safe_load(config_content, permitted_classes: [Symbol], symbolize_names: true)
          puts Oj.dump({ path: active_path, config: yaml_data }, mode: :compat, indent: 2)
        else
          puts pastel.bold("# #{active_path}")
          puts config_content
        end
      end

      desc "defaults", "Show the bundled default configuration"
      def defaults
        defaults_content = File.read(Config::DEFAULTS_PATH)

        if options[:json]
          yaml_data = YAML.safe_load(defaults_content, permitted_classes: [Symbol], symbolize_names: true)
          puts Oj.dump(yaml_data, mode: :compat, indent: 2)
        else
          puts pastel.bold("# TrakFlow Bundled Defaults")
          puts pastel.dim("# #{Config::DEFAULTS_PATH}")
          puts ""
          puts defaults_content
        end
      end

      # Show defaults when no subcommand is given
      default_task :defaults

      desc "reset", "Reset configuration to defaults"
      option :global, aliases: "-g", type: :boolean, default: false, desc: "Reset global (XDG) config"
      option :force, aliases: "-f", type: :boolean, default: false, desc: "Overwrite existing config"
      def reset
        target_path = determine_config_path(options[:global])
        target_dir = File.dirname(target_path)

        if File.exist?(target_path) && !options[:force]
          output({ success: false, error: "Config file already exists. Use --force to overwrite." }) do
            puts pastel.red("Config file already exists at #{target_path}")
            puts "Use --force to overwrite"
          end
          return
        end

        FileUtils.mkdir_p(target_dir)
        FileUtils.cp(Config::DEFAULTS_PATH, target_path)

        output({ success: true, path: target_path }) do
          puts pastel.green("Configuration reset to defaults at #{target_path}")
        end
      end

      desc "get KEY", "Get a configuration value (e.g., 'database.path', 'mcp.port')"
      def get(key)
        value = get_nested_value(key)

        if value.nil?
          output({ key: key, value: nil, error: "Key not found" }) do
            puts pastel.red("Key '#{key}' not found in configuration")
          end
          return
        end

        output({ key: key, value: serialize_value(value) }) do
          if value.is_a?(TrakFlow::ConfigSection)
            puts value.to_h.to_yaml.lines[1..].join
          else
            puts value
          end
        end
      end

      desc "set KEY VALUE", "Set a configuration value (e.g., 'database.path /path/to/db')"
      def set(key, value)
        config_path = find_writable_config_path

        # Load existing config or create new
        config_data = if File.exist?(config_path)
                        YAML.safe_load(File.read(config_path), permitted_classes: [Symbol], symbolize_names: true) || {}
                      else
                        {}
                      end

        # Ensure defaults section exists
        config_data[:defaults] ||= {}

        # Parse the value (convert to appropriate type)
        parsed_value = parse_value(value)

        # Set the nested value
        set_nested_value(config_data[:defaults], key, parsed_value)

        # Ensure directory exists
        FileUtils.mkdir_p(File.dirname(config_path))

        # Write the config file
        File.write(config_path, config_data.to_yaml)

        # Reset config to pick up new values
        TrakFlow.reset_config!

        output({ key: key, value: parsed_value, path: config_path }) do
          puts pastel.green("Set #{key} = #{parsed_value}")
          puts "Configuration saved to #{config_path}"
        end
      end

      desc "path", "Show configuration file paths"
      def path
        project_path = File.expand_path(PROJECT_CONFIG_PATH)
        project_exists = File.exist?(project_path)
        xdg_exists = File.exist?(XDG_CONFIG_PATH)

        paths = {
          defaults: Config::DEFAULTS_PATH,
          xdg: { path: XDG_CONFIG_PATH, exists: xdg_exists },
          project: { path: project_path, exists: project_exists },
          active: find_active_config_path
        }

        output(paths) do
          puts "Configuration paths:"
          puts "  Defaults:  #{Config::DEFAULTS_PATH}"
          puts "  XDG:       #{XDG_CONFIG_PATH} #{xdg_exists ? pastel.green('(exists)') : pastel.dim('(not found)')}"
          puts "  Project:   #{project_path} #{project_exists ? pastel.green('(exists)') : pastel.dim('(not found)')}"
          puts ""
          puts "Active config: #{find_active_config_path || pastel.dim('(defaults only)')}"
        end
      end

      private

      def pastel
        @pastel ||= Pastel.new
      end

      def output(json_data, &human_block)
        if options[:json]
          puts Oj.dump(json_data, mode: :compat, indent: 2)
        else
          human_block.call
        end
      end

      def determine_config_path(global)
        if global
          XDG_CONFIG_PATH
        elsif File.exist?(PROJECT_CONFIG_PATH)
          File.expand_path(PROJECT_CONFIG_PATH)
        elsif File.directory?(".trak_flow")
          File.expand_path(PROJECT_CONFIG_PATH)
        else
          XDG_CONFIG_PATH
        end
      end

      def find_writable_config_path
        # Prefer project config if .trak_flow exists, otherwise use XDG
        if File.directory?(".trak_flow")
          File.expand_path(PROJECT_CONFIG_PATH)
        else
          XDG_CONFIG_PATH
        end
      end

      def find_active_config_path
        project_path = File.expand_path(PROJECT_CONFIG_PATH)
        return project_path if File.exist?(project_path)
        return XDG_CONFIG_PATH if File.exist?(XDG_CONFIG_PATH)

        nil
      end

      def get_nested_value(key)
        parts = key.split(".")
        value = TrakFlow.config

        parts.each do |part|
          if value.respond_to?(part)
            value = value.send(part)
          elsif value.respond_to?(:[])
            value = value[part.to_sym] || value[part]
          else
            return nil
          end
          return nil if value.nil?
        end

        value
      end

      def set_nested_value(hash, key, value)
        parts = key.split(".")
        current = hash

        parts[0...-1].each do |part|
          current[part.to_sym] ||= {}
          current = current[part.to_sym]
        end

        current[parts.last.to_sym] = value
      end

      def parse_value(value)
        # Try to parse as various types
        case value.downcase
        when "true" then true
        when "false" then false
        when "nil", "null" then nil
        else
          # Try integer
          if value.match?(/\A-?\d+\z/)
            value.to_i
          # Try float
          elsif value.match?(/\A-?\d+\.\d+\z/)
            value.to_f
          else
            # Keep as string, expand ~ for paths
            value.start_with?("~") ? File.expand_path(value) : value
          end
        end
      end

      def serialize_value(value)
        if value.is_a?(TrakFlow::ConfigSection)
          value.to_h
        else
          value
        end
      end
    end
  end
end
