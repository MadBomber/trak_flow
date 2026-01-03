# frozen_string_literal: true

require 'anyway_config'
require 'yaml'

require_relative 'config/section'

module TrakFlow
  # TrakFlow Configuration using Anyway Config
  #
  # Schema is defined in lib/trak_flow/config/defaults.yml (single source of truth)
  # Configuration uses nested sections for better organization:
  #   - TrakFlow.config.output.json
  #   - TrakFlow.config.daemon.auto_start
  #   - TrakFlow.config.export.error_policy
  #
  # Configuration sources (lowest to highest priority):
  # 1. Bundled defaults: lib/trak_flow/config/defaults.yml (ships with gem)
  # 2. XDG user config: ~/.config/trak_flow/trak_flow.yml
  # 3. Project config: ./.trak_flow/config.yml
  # 4. Environment variables (TF_*)
  # 5. Explicit values passed to configure block
  #
  # @example Configure with environment variables
  #   export TF_OUTPUT__JSON=true
  #   export TF_DAEMON__AUTO_START=false
  #   export TF_ACTOR=robot
  #
  # @example Configure with Ruby block
  #   TrakFlow.configure do |config|
  #     config.output.json = true
  #     config.daemon.auto_start = false
  #   end
  #
  class Config < Anyway::Config
    config_name :trak_flow
    env_prefix :tf

    # ==========================================================================
    # Schema Definition (loaded from defaults.yml - single source of truth)
    # ==========================================================================

    DEFAULTS_PATH = File.expand_path('config/defaults.yml', __dir__).freeze

    begin
      defaults_content = File.read(DEFAULTS_PATH)
      raw_yaml = YAML.safe_load(
        defaults_content,
        permitted_classes: [Symbol],
        symbolize_names: true,
        aliases: true
      ) || {}
      SCHEMA = raw_yaml[:defaults] || {}
    rescue StandardError => e
      raise TrakFlow::ConfigurationError,
        "Could not load schema from #{DEFAULTS_PATH}: #{e.message}"
    end

    # Nested section attributes (defined as hashes, converted to ConfigSection)
    attr_config :output, :daemon, :sync, :create, :validation, :id, :import, :export, :database, :mcp

    # Top-level scalar attributes
    attr_config :actor

    # ==========================================================================
    # Type Coercion
    # ==========================================================================

    def self.config_section_with_defaults(section_key)
      defaults = SCHEMA[section_key] || {}
      ->(v) {
        return v if v.is_a?(ConfigSection)
        incoming = v || {}
        merged = deep_merge_hashes(defaults.dup, incoming)
        ConfigSection.new(merged)
      }
    end

    def self.deep_merge_hashes(base, overlay)
      base.merge(overlay) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge_hashes(old_val, new_val)
        else
          new_val.nil? ? old_val : new_val
        end
      end
    end

    coerce_types(
      output: config_section_with_defaults(:output),
      daemon: config_section_with_defaults(:daemon),
      sync: config_section_with_defaults(:sync),
      create: config_section_with_defaults(:create),
      validation: config_section_with_defaults(:validation),
      id: config_section_with_defaults(:id),
      import: config_section_with_defaults(:import),
      export: config_section_with_defaults(:export),
      database: config_section_with_defaults(:database),
      mcp: config_section_with_defaults(:mcp)
    )

    on_load :setup_defaults

    # ==========================================================================
    # Convenience Accessors (for backward compatibility)
    # ==========================================================================

    def json?
      output.json
    end

    def no_daemon?
      daemon.disabled
    end

    def auto_start_daemon?
      daemon.auto_start
    end

    def flush_debounce
      daemon.flush_debounce
    end

    def no_auto_flush?
      !sync.auto_flush
    end

    def no_auto_import?
      !sync.auto_import
    end

    def no_push?
      !sync.push
    end

    def require_description?
      create.require_description
    end

    def validation_on_create
      validation.on_create
    end

    def validation_on_sync
      validation.on_sync
    end

    def max_collision_prob
      id.max_collision_prob
    end

    def min_hash_length
      id.min_hash_length
    end

    def max_hash_length
      id.max_hash_length
    end

    def orphan_handling
      import.orphan_handling
    end

    def import_error_policy
      import.error_policy
    end

    def error_policy
      export.error_policy
    end

    def retry_attempts
      export.retry_attempts
    end

    def retry_backoff_ms
      export.retry_backoff_ms
    end

    def skip_encoding_errors?
      export.skip_encoding_errors
    end

    # ==========================================================================
    # Legacy API Support (for backward compatibility)
    # ==========================================================================

    LEGACY_KEY_MAP = {
      'json' => %i[output json],
      'stealth' => %i[output stealth],
      'no_daemon' => %i[daemon disabled],
      'no_auto_flush' => %i[sync auto_flush],
      'no_auto_import' => %i[sync auto_import],
      'no_push' => %i[sync push],
      'create.require_description' => %i[create require_description],
      'validation.on_create' => %i[validation on_create],
      'validation.on_sync' => %i[validation on_sync],
      'flush_debounce' => %i[daemon flush_debounce],
      'auto_start_daemon' => %i[daemon auto_start],
      'max_collision_prob' => %i[id max_collision_prob],
      'min_hash_length' => %i[id min_hash_length],
      'max_hash_length' => %i[id max_hash_length],
      'import.orphan_handling' => %i[import orphan_handling],
      'import.error_policy' => %i[import error_policy],
      'export.error_policy' => %i[export error_policy],
      'export.retry_attempts' => %i[export retry_attempts],
      'export.retry_backoff_ms' => %i[export retry_backoff_ms],
      'export.skip_encoding_errors' => %i[export skip_encoding_errors],
      'actor' => [:actor]
    }.freeze

    def get(key)
      mapping = LEGACY_KEY_MAP[key.to_s]
      return nil unless mapping

      if mapping.is_a?(Array)
        value = self
        mapping.each { |k| value = value.respond_to?(k) ? value.send(k) : value[k] }
        value
      elsif mapping.is_a?(Proc)
        nil
      else
        send(mapping)
      end
    end

    def set(key, value)
      mapping = LEGACY_KEY_MAP[key.to_s]
      return unless mapping

      if mapping.is_a?(Array)
        if mapping.length == 1
          send("#{mapping[0]}=", value)
        else
          section = send(mapping[0])
          section.send("#{mapping[1]}=", value)
        end
      end
    end

    private

    def setup_defaults
      # Ensure all sections are initialized with defaults even when no config files exist
      # Manually apply coercion since it only fires when values come from config sources
      self.output = self.class.config_section_with_defaults(:output).call(output) unless output.is_a?(ConfigSection)
      self.daemon = self.class.config_section_with_defaults(:daemon).call(daemon) unless daemon.is_a?(ConfigSection)
      self.sync = self.class.config_section_with_defaults(:sync).call(sync) unless sync.is_a?(ConfigSection)
      self.create = self.class.config_section_with_defaults(:create).call(create) unless create.is_a?(ConfigSection)
      self.validation = self.class.config_section_with_defaults(:validation).call(validation) unless validation.is_a?(ConfigSection)
      self.id = self.class.config_section_with_defaults(:id).call(self.id) unless self.id.is_a?(ConfigSection)
      self.import = self.class.config_section_with_defaults(:import).call(self.import) unless self.import.is_a?(ConfigSection)
      self.export = self.class.config_section_with_defaults(:export).call(self.export) unless self.export.is_a?(ConfigSection)
      self.database = self.class.config_section_with_defaults(:database).call(self.database) unless self.database.is_a?(ConfigSection)
      self.mcp = self.class.config_section_with_defaults(:mcp).call(self.mcp) unless self.mcp.is_a?(ConfigSection)
      self.actor ||= ENV.fetch('USER', 'unknown')
    end
  end

  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield(config) if block_given?
      config
    end

    def reset_config!
      @config = nil
    end
  end
end
