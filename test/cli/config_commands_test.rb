# frozen_string_literal: true

require_relative "cli_test_helper"

class ConfigCommandsTest < Minitest::Test
  include CLITestHelper

  def setup
    setup_temp_trak_flow
  end

  def teardown
    teardown_temp_trak_flow
  end

  # === defaults (default command) ===

  def test_config_defaults_outputs_bundled_defaults
    result = run_cli("config", "defaults")
    assert_match(/TrakFlow Bundled Defaults/, result.stdout)
    assert_match(/defaults:/, result.stdout)
    assert_match(/output:/, result.stdout)
    assert_match(/database:/, result.stdout)
    assert_match(/mcp:/, result.stdout)
  end

  def test_config_defaults_json_output
    result = run_cli_json("config", "defaults")
    assert result["defaults"]
    assert result["defaults"]["output"]
    assert result["defaults"]["database"]
    assert result["defaults"]["mcp"]
  end

  def test_config_default_command_is_defaults
    # Running 'config' without subcommand should show bundled defaults
    result = run_cli("config")
    assert_match(/TrakFlow Bundled Defaults/, result.stdout)
  end

  # === show ===

  def test_config_show_no_config_file
    # Without a project config file, show should either:
    # 1. Show "No configuration file found" if no XDG config exists
    # 2. Show the XDG config if it exists globally
    result = run_cli("config", "show")

    xdg_config_exists = File.exist?(File.expand_path("~/.config/trak_flow/trak_flow.yml"))
    if xdg_config_exists
      # XDG config exists, show displays it
      assert_match(/\.config\/trak_flow/, result.stdout)
    else
      # No config file anywhere
      assert_match(/No configuration file found/, result.stdout)
      assert_match(/tf config reset/, result.stdout)
    end
  end

  def test_config_show_displays_current_config
    init_trak_flow
    run_cli("config", "reset", "--force")

    result = run_cli("config", "show")
    # Should show the config file path and content
    assert_match(/\.trak_flow/, result.stdout)
    assert_match(/defaults:/, result.stdout)
  end

  def test_config_show_json_output
    init_trak_flow
    run_cli("config", "reset", "--force")

    result = run_cli_json("config", "show")
    assert result["path"]
    assert result["config"]
    assert result["config"]["defaults"]
  end

  # === get ===

  def test_config_get_simple_value
    result = run_cli("config", "get", "mcp.port")
    assert_match(/3333/, result.stdout)
  end

  def test_config_get_nested_value
    # Use output.json since database.path is overridden in test setup
    result = run_cli("config", "get", "output.json")
    assert_match(/false/, result.stdout)
  end

  def test_config_get_section
    result = run_cli("config", "get", "output")
    assert_match(/json/, result.stdout)
    assert_match(/stealth/, result.stdout)
  end

  def test_config_get_nonexistent_key
    result = run_cli("config", "get", "nonexistent.key")
    assert_match(/not found/, result.stdout)
  end

  def test_config_get_json_output
    result = run_cli_json("config", "get", "mcp.port")
    assert_equal "mcp.port", result["key"]
    assert_equal 3333, result["value"]
  end

  # === set ===

  def test_config_set_creates_config_file
    # Initialize TrakFlow so we have a .trak_flow directory
    init_trak_flow

    result = run_cli("config", "set", "mcp.port", "8080")
    assert_match(/Set mcp\.port = 8080/, result.stdout)

    config_file = File.join(@temp_dir, ".trak_flow", "config.yml")
    assert File.exist?(config_file)

    content = YAML.safe_load(File.read(config_file), permitted_classes: [Symbol], symbolize_names: true)
    assert_equal 8080, content[:defaults][:mcp][:port]
  end

  def test_config_set_boolean_true
    init_trak_flow

    run_cli("config", "set", "output.json", "true")

    config_file = File.join(@temp_dir, ".trak_flow", "config.yml")
    content = YAML.safe_load(File.read(config_file), permitted_classes: [Symbol], symbolize_names: true)
    assert_equal true, content[:defaults][:output][:json]
  end

  def test_config_set_boolean_false
    init_trak_flow

    run_cli("config", "set", "output.stealth", "false")

    config_file = File.join(@temp_dir, ".trak_flow", "config.yml")
    content = YAML.safe_load(File.read(config_file), permitted_classes: [Symbol], symbolize_names: true)
    assert_equal false, content[:defaults][:output][:stealth]
  end

  def test_config_set_string_value
    init_trak_flow

    run_cli("config", "set", "database.path", "/custom/path/db.sqlite")

    config_file = File.join(@temp_dir, ".trak_flow", "config.yml")
    content = YAML.safe_load(File.read(config_file), permitted_classes: [Symbol], symbolize_names: true)
    assert_equal "/custom/path/db.sqlite", content[:defaults][:database][:path]
  end

  def test_config_set_json_output
    init_trak_flow

    result = run_cli_json("config", "set", "mcp.port", "9999")
    assert_equal "mcp.port", result["key"]
    assert_equal 9999, result["value"]
    assert result["path"]
  end

  # === path ===

  def test_config_path_shows_all_paths
    result = run_cli("config", "path")
    assert_match(/Defaults:/, result.stdout)
    assert_match(/XDG:/, result.stdout)
    assert_match(/Project:/, result.stdout)
    assert_match(/Active config:/, result.stdout)
  end

  def test_config_path_json_output
    result = run_cli_json("config", "path")
    assert result["defaults"]
    assert result["xdg"]
    assert result["project"]
  end

  # === reset ===

  def test_config_reset_creates_config_file
    init_trak_flow

    result = run_cli("config", "reset", "--force")
    assert_match(/Configuration reset to defaults/, result.stdout)

    config_file = File.join(@temp_dir, ".trak_flow", "config.yml")
    assert File.exist?(config_file)
  end

  def test_config_reset_fails_without_force_if_exists
    init_trak_flow

    # Create config file first
    run_cli("config", "reset", "--force")

    # Try again without force
    result = run_cli("config", "reset")
    assert_match(/already exists/, result.stdout)
  end

  def test_config_reset_json_output
    init_trak_flow

    result = run_cli_json("config", "reset", "--force")
    assert_equal true, result["success"]
    assert result["path"]
  end
end
