# frozen_string_literal: true

require_relative "../test_helper"

class ConfigTest < Minitest::Test
  # Note: These tests do NOT use TrakFlowTestHelper because config tests
  # should run in the project directory where defaults.yml is accessible

  def teardown
    TrakFlow.reset_config!
  end

  # ==========================================================================
  # TrakFlow.config
  # ==========================================================================

  def test_config_returns_config_instance
    assert_instance_of TrakFlow::Config, TrakFlow.config
  end

  def test_config_returns_same_instance
    config1 = TrakFlow.config
    config2 = TrakFlow.config
    assert_same config1, config2
  end

  # ==========================================================================
  # TrakFlow.configure
  # ==========================================================================

  def test_configure_yields_config
    yielded = nil
    TrakFlow.configure { |c| yielded = c }
    assert_instance_of TrakFlow::Config, yielded
  end

  def test_configure_returns_config
    result = TrakFlow.configure {}
    assert_instance_of TrakFlow::Config, result
  end

  def test_configure_without_block_returns_config
    result = TrakFlow.configure
    assert_instance_of TrakFlow::Config, result
  end

  def test_configure_allows_setting_values
    TrakFlow.configure do |config|
      config.output.json = true
    end
    assert_equal true, TrakFlow.config.output.json
  end

  # ==========================================================================
  # TrakFlow.reset_config!
  # ==========================================================================

  def test_reset_config_clears_cached_instance
    config1 = TrakFlow.config
    TrakFlow.reset_config!
    config2 = TrakFlow.config
    refute_same config1, config2
  end

  # ==========================================================================
  # Nested section accessors
  # ==========================================================================

  def test_output_section_exists
    assert_instance_of TrakFlow::ConfigSection, TrakFlow.config.output
  end

  def test_daemon_section_exists
    assert_instance_of TrakFlow::ConfigSection, TrakFlow.config.daemon
  end

  def test_sync_section_exists
    assert_instance_of TrakFlow::ConfigSection, TrakFlow.config.sync
  end

  def test_create_section_exists
    assert_instance_of TrakFlow::ConfigSection, TrakFlow.config.create
  end

  def test_validation_section_exists
    assert_instance_of TrakFlow::ConfigSection, TrakFlow.config.validation
  end

  def test_id_section_exists
    assert_instance_of TrakFlow::ConfigSection, TrakFlow.config.id
  end

  def test_import_section_exists
    assert_instance_of TrakFlow::ConfigSection, TrakFlow.config.import
  end

  def test_export_section_exists
    assert_instance_of TrakFlow::ConfigSection, TrakFlow.config.export
  end

  # ==========================================================================
  # Default values from defaults.yml
  # ==========================================================================

  def test_output_json_default
    assert_equal false, TrakFlow.config.output.json
  end

  def test_output_stealth_default
    assert_equal false, TrakFlow.config.output.stealth
  end

  def test_daemon_disabled_default
    assert_equal false, TrakFlow.config.daemon.disabled
  end

  def test_daemon_auto_start_default
    assert_equal true, TrakFlow.config.daemon.auto_start
  end

  def test_daemon_flush_debounce_default
    assert_equal 5, TrakFlow.config.daemon.flush_debounce
  end

  def test_sync_auto_flush_default
    assert_equal true, TrakFlow.config.sync.auto_flush
  end

  def test_sync_auto_import_default
    assert_equal true, TrakFlow.config.sync.auto_import
  end

  def test_sync_push_default
    assert_equal true, TrakFlow.config.sync.push
  end

  def test_create_require_description_default
    assert_equal false, TrakFlow.config.create.require_description
  end

  def test_validation_on_create_default
    assert_equal "none", TrakFlow.config.validation.on_create
  end

  def test_validation_on_sync_default
    assert_equal "none", TrakFlow.config.validation.on_sync
  end

  def test_id_max_collision_prob_default
    assert_equal 0.25, TrakFlow.config.id.max_collision_prob
  end

  def test_id_min_hash_length_default
    assert_equal 4, TrakFlow.config.id.min_hash_length
  end

  def test_id_max_hash_length_default
    assert_equal 8, TrakFlow.config.id.max_hash_length
  end

  def test_import_orphan_handling_default
    assert_equal "allow", TrakFlow.config.import.orphan_handling
  end

  def test_import_error_policy_default
    assert_equal "warn", TrakFlow.config.import.error_policy
  end

  def test_export_error_policy_default
    assert_equal "strict", TrakFlow.config.export.error_policy
  end

  def test_export_retry_attempts_default
    assert_equal 3, TrakFlow.config.export.retry_attempts
  end

  def test_export_retry_backoff_ms_default
    assert_equal 100, TrakFlow.config.export.retry_backoff_ms
  end

  def test_export_skip_encoding_errors_default
    assert_equal false, TrakFlow.config.export.skip_encoding_errors
  end

  def test_actor_defaults_to_user_env
    assert_equal ENV.fetch("USER", "unknown"), TrakFlow.config.actor
  end

  # ==========================================================================
  # Convenience accessors
  # ==========================================================================

  def test_json_predicate
    assert_equal false, TrakFlow.config.json?
  end

  def test_no_daemon_predicate
    assert_equal false, TrakFlow.config.no_daemon?
  end

  def test_auto_start_daemon_predicate
    assert_equal true, TrakFlow.config.auto_start_daemon?
  end

  def test_flush_debounce_accessor
    assert_equal 5, TrakFlow.config.flush_debounce
  end

  def test_no_auto_flush_predicate
    assert_equal false, TrakFlow.config.no_auto_flush?
  end

  def test_no_auto_import_predicate
    assert_equal false, TrakFlow.config.no_auto_import?
  end

  def test_no_push_predicate
    assert_equal false, TrakFlow.config.no_push?
  end

  def test_require_description_predicate
    assert_equal false, TrakFlow.config.require_description?
  end

  def test_validation_on_create_accessor
    assert_equal "none", TrakFlow.config.validation_on_create
  end

  def test_validation_on_sync_accessor
    assert_equal "none", TrakFlow.config.validation_on_sync
  end

  def test_max_collision_prob_accessor
    assert_equal 0.25, TrakFlow.config.max_collision_prob
  end

  def test_min_hash_length_accessor
    assert_equal 4, TrakFlow.config.min_hash_length
  end

  def test_max_hash_length_accessor
    assert_equal 8, TrakFlow.config.max_hash_length
  end

  def test_orphan_handling_accessor
    assert_equal "allow", TrakFlow.config.orphan_handling
  end

  def test_import_error_policy_accessor
    assert_equal "warn", TrakFlow.config.import_error_policy
  end

  def test_error_policy_accessor
    assert_equal "strict", TrakFlow.config.error_policy
  end

  def test_retry_attempts_accessor
    assert_equal 3, TrakFlow.config.retry_attempts
  end

  def test_retry_backoff_ms_accessor
    assert_equal 100, TrakFlow.config.retry_backoff_ms
  end

  def test_skip_encoding_errors_predicate
    assert_equal false, TrakFlow.config.skip_encoding_errors?
  end

  # ==========================================================================
  # Legacy API: get
  # ==========================================================================

  def test_get_json
    assert_equal false, TrakFlow.config.get("json")
  end

  def test_get_stealth
    assert_equal false, TrakFlow.config.get("stealth")
  end

  def test_get_no_daemon
    assert_equal false, TrakFlow.config.get("no_daemon")
  end

  def test_get_no_auto_flush
    assert_equal true, TrakFlow.config.get("no_auto_flush")
  end

  def test_get_no_auto_import
    assert_equal true, TrakFlow.config.get("no_auto_import")
  end

  def test_get_no_push
    assert_equal true, TrakFlow.config.get("no_push")
  end

  def test_get_flush_debounce
    assert_equal 5, TrakFlow.config.get("flush_debounce")
  end

  def test_get_auto_start_daemon
    assert_equal true, TrakFlow.config.get("auto_start_daemon")
  end

  def test_get_nested_key
    assert_equal false, TrakFlow.config.get("create.require_description")
  end

  def test_get_validation_on_create
    assert_equal "none", TrakFlow.config.get("validation.on_create")
  end

  def test_get_validation_on_sync
    assert_equal "none", TrakFlow.config.get("validation.on_sync")
  end

  def test_get_max_collision_prob
    assert_equal 0.25, TrakFlow.config.get("max_collision_prob")
  end

  def test_get_min_hash_length
    assert_equal 4, TrakFlow.config.get("min_hash_length")
  end

  def test_get_max_hash_length
    assert_equal 8, TrakFlow.config.get("max_hash_length")
  end

  def test_get_import_orphan_handling
    assert_equal "allow", TrakFlow.config.get("import.orphan_handling")
  end

  def test_get_import_error_policy
    assert_equal "warn", TrakFlow.config.get("import.error_policy")
  end

  def test_get_export_error_policy
    assert_equal "strict", TrakFlow.config.get("export.error_policy")
  end

  def test_get_export_retry_attempts
    assert_equal 3, TrakFlow.config.get("export.retry_attempts")
  end

  def test_get_export_retry_backoff_ms
    assert_equal 100, TrakFlow.config.get("export.retry_backoff_ms")
  end

  def test_get_export_skip_encoding_errors
    assert_equal false, TrakFlow.config.get("export.skip_encoding_errors")
  end

  def test_get_actor
    assert_equal ENV.fetch("USER", "unknown"), TrakFlow.config.get("actor")
  end

  def test_get_unknown_key_returns_nil
    assert_nil TrakFlow.config.get("unknown_key")
  end

  def test_get_accepts_symbol
    assert_equal false, TrakFlow.config.get(:json)
  end

  # ==========================================================================
  # Legacy API: set
  # ==========================================================================

  def test_set_json
    TrakFlow.config.set("json", true)
    assert_equal true, TrakFlow.config.output.json
  end

  def test_set_stealth
    TrakFlow.config.set("stealth", true)
    assert_equal true, TrakFlow.config.output.stealth
  end

  def test_set_nested_key
    TrakFlow.config.set("create.require_description", true)
    assert_equal true, TrakFlow.config.create.require_description
  end

  def test_set_actor
    TrakFlow.config.set("actor", "test_user")
    assert_equal "test_user", TrakFlow.config.actor
  end

  def test_set_unknown_key_does_nothing
    TrakFlow.config.set("unknown_key", "value")
    assert_nil TrakFlow.config.get("unknown_key")
  end

  def test_set_accepts_symbol
    TrakFlow.config.set(:json, true)
    assert_equal true, TrakFlow.config.output.json
  end

  # ==========================================================================
  # SCHEMA constant
  # ==========================================================================

  def test_schema_is_loaded
    refute_empty TrakFlow::Config::SCHEMA
  end

  def test_schema_contains_expected_sections
    assert TrakFlow::Config::SCHEMA.key?(:output)
    assert TrakFlow::Config::SCHEMA.key?(:daemon)
    assert TrakFlow::Config::SCHEMA.key?(:sync)
    assert TrakFlow::Config::SCHEMA.key?(:create)
    assert TrakFlow::Config::SCHEMA.key?(:validation)
    assert TrakFlow::Config::SCHEMA.key?(:id)
    assert TrakFlow::Config::SCHEMA.key?(:import)
    assert TrakFlow::Config::SCHEMA.key?(:export)
  end

  # ==========================================================================
  # DEFAULTS_PATH constant
  # ==========================================================================

  def test_defaults_path_exists
    assert File.exist?(TrakFlow::Config::DEFAULTS_PATH)
  end

  def test_defaults_path_is_frozen
    assert TrakFlow::Config::DEFAULTS_PATH.frozen?
  end
end
