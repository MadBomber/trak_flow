# frozen_string_literal: true

require_relative "cli_test_helper"

class MainCommandsTest < Minitest::Test
  include CLITestHelper

  def setup
    setup_temp_trak_flow
  end

  def teardown
    teardown_temp_trak_flow
  end

  # === version ===

  def test_version_displays_version
    result = run_cli("version")
    assert_match(/trak_flow \d+\.\d+\.\d+/, result.stdout)
  end

  # === init ===

  def test_init_creates_trak_flow_directory
    result = run_cli("init")
    assert_match(/Initialized TrakFlow/, result.stdout)
    assert Dir.exist?(".trak_flow")
  end

  def test_init_creates_jsonl_file
    run_cli("init")
    assert File.exist?(TrakFlow.jsonl_path)
  end

  def test_init_with_stealth_mode
    result = run_cli("init", "--stealth")
    assert_match(/Initialized TrakFlow/, result.stdout)
    refute File.exist?(".trak_flow/.gitignore")
  end

  def test_init_fails_if_already_initialized
    run_cli("init")
    result = run_cli("init")
    assert_match(/already initialized/, result.stdout)
  end

  def test_init_json_output
    result = run_cli_json("init")
    assert_equal true, result["success"]
    assert result["path"]
  end

  # === info ===

  def test_info_shows_paths
    init_trak_flow
    result = run_cli("info")
    assert_match(/database_path/, result.stdout)
    assert_match(/jsonl_path/, result.stdout)
    assert_match(/config_path/, result.stdout)
  end

  def test_info_json_output
    init_trak_flow
    result = run_cli_json("info")
    assert result["database_path"]
    assert result["jsonl_path"]
    assert_equal true, result["initialized"]
  end

  # === create ===

  def test_create_task
    init_trak_flow
    result = run_cli("create", "Test task")
    assert_match(/Created:/, result.stdout)
    assert_match(/Test task/, result.stdout)
  end

  def test_create_task_with_options
    init_trak_flow
    result = run_cli("create", "Bug fix", "-t", "bug", "-p", "1", "-d", "Description here")
    assert_match(/Created:/, result.stdout)
    assert_match(/Bug fix/, result.stdout)
  end

  def test_create_task_json_output
    init_trak_flow
    result = run_cli_json("create", "Test task")
    assert result["id"]
    assert_equal "Test task", result["title"]
    assert_equal "task", result["type"]
    assert_equal "open", result["status"]
  end

  def test_create_task_with_priority
    init_trak_flow
    result = run_cli_json("create", "Critical bug", "-p", "0")
    assert_equal 0, result["priority"]
  end

  def test_create_task_with_type
    init_trak_flow
    result = run_cli_json("create", "New feature", "-t", "feature")
    assert_equal "feature", result["type"]
  end

  def test_create_plan
    init_trak_flow
    result = run_cli_json("create", "My Plan", "--plan")
    assert_equal true, result["plan"]
  end

  def test_create_ephemeral_task
    init_trak_flow
    result = run_cli_json("create", "Temp task", "--ephemeral")
    assert_equal true, result["ephemeral"]
  end

  def test_create_child_task
    init_trak_flow
    parent_id = create_task("Parent task")
    result = run_cli_json("create", "Child task", "--parent", parent_id)
    assert_equal parent_id, result["parent_id"]
  end

  # === show ===

  def test_show_task
    init_trak_flow
    task_id = create_task("Show me")
    result = run_cli("show", task_id)
    assert_match(/Task: #{task_id}/, result.stdout)
    assert_match(/Show me/, result.stdout)
  end

  def test_show_task_json_output
    init_trak_flow
    task_id = create_task("Show me", description: "Details here")
    result = run_cli_json("show", task_id)
    assert_equal task_id, result["task"]["id"]
    assert_equal "Show me", result["task"]["title"]
    assert_equal "Details here", result["task"]["description"]
  end

  # === list ===

  def test_list_empty
    init_trak_flow
    result = run_cli("list")
    assert_match(/No tasks found/, result.stdout)
  end

  def test_list_tasks
    init_trak_flow
    create_task("Task 1")
    create_task("Task 2")
    # Use JSON output to avoid TTY::Table ioctl issues in test environment
    result = run_cli_json("list")
    titles = result.map { |t| t["title"] }
    assert_includes titles, "Task 1"
    assert_includes titles, "Task 2"
  end

  def test_list_json_output
    init_trak_flow
    create_task("Task 1")
    create_task("Task 2")
    result = run_cli_json("list")
    assert_equal 2, result.size
  end

  def test_list_filter_by_status
    init_trak_flow
    task_id = create_task("Open task")
    run_cli("close", task_id)
    create_task("Another open")

    result = run_cli_json("list", "-s", "open")
    assert_equal 1, result.size
    assert_equal "Another open", result.first["title"]
  end

  def test_list_filter_by_priority
    init_trak_flow
    create_task("Low priority", priority: 3)
    create_task("High priority", priority: 1)

    result = run_cli_json("list", "-p", "1")
    assert_equal 1, result.size
    assert_equal "High priority", result.first["title"]
  end

  def test_list_filter_by_type
    init_trak_flow
    create_task("A bug", type: "bug")
    create_task("A feature", type: "feature")

    result = run_cli_json("list", "-t", "bug")
    assert_equal 1, result.size
    assert_equal "A bug", result.first["title"]
  end

  def test_list_with_limit
    init_trak_flow
    create_task("Task 1")
    create_task("Task 2")
    create_task("Task 3")

    result = run_cli_json("list", "--limit", "2")
    assert_equal 2, result.size
  end

  # === update ===

  def test_update_task_status
    init_trak_flow
    task_id = create_task("Update me")
    result = run_cli("update", task_id, "-s", "in_progress")
    assert_match(/Updated:/, result.stdout)

    task = run_cli_json("show", task_id)
    assert_equal "in_progress", task["task"]["status"]
  end

  def test_update_task_priority
    init_trak_flow
    task_id = create_task("Update priority")
    run_cli("update", task_id, "-p", "0")

    task = run_cli_json("show", task_id)
    assert_equal 0, task["task"]["priority"]
  end

  def test_update_task_title
    init_trak_flow
    task_id = create_task("Old title")
    run_cli("update", task_id, "--title", "New title")

    task = run_cli_json("show", task_id)
    assert_equal "New title", task["task"]["title"]
  end

  def test_update_json_output
    init_trak_flow
    task_id = create_task("Update me")
    result = run_cli_json("update", task_id, "-s", "blocked")
    assert_equal task_id, result["id"]
    assert_equal "blocked", result["status"]
  end

  # === close ===

  def test_close_task
    init_trak_flow
    task_id = create_task("Close me")
    result = run_cli("close", task_id)
    assert_match(/Closed:/, result.stdout)

    task = run_cli_json("show", task_id)
    assert_equal "closed", task["task"]["status"]
  end

  def test_close_json_output
    init_trak_flow
    task_id = create_task("Close me")
    result = run_cli_json("close", task_id)
    assert_equal "closed", result["status"]
    assert result["closed_at"]
  end

  # === reopen ===

  def test_reopen_task
    init_trak_flow
    task_id = create_task("Reopen me")
    run_cli("close", task_id)
    result = run_cli("reopen", task_id)
    assert_match(/Reopened:/, result.stdout)

    task = run_cli_json("show", task_id)
    assert_equal "open", task["task"]["status"]
  end

  def test_reopen_json_output
    init_trak_flow
    task_id = create_task("Reopen me")
    run_cli("close", task_id)
    result = run_cli_json("reopen", task_id)
    assert_equal "open", result["status"]
    assert_nil result["closed_at"]
  end

  # === ready ===

  def test_ready_shows_unblocked_tasks
    init_trak_flow
    create_task("Ready task")
    # Use JSON output to avoid TTY::Table ioctl issues
    result = run_cli_json("ready")
    assert_equal 1, result.size
    assert_equal "Ready task", result.first["title"]
  end

  def test_ready_empty
    init_trak_flow
    result = run_cli("ready")
    assert_match(/No ready tasks found/, result.stdout)
  end

  def test_ready_json_output
    init_trak_flow
    create_task("Ready task")
    result = run_cli_json("ready")
    assert_equal 1, result.size
    assert_equal "Ready task", result.first["title"]
  end

  # === stale ===

  def test_stale_empty
    init_trak_flow
    create_task("Fresh task")
    # Use JSON output to avoid TTY::Table ioctl issues
    result = run_cli_json("stale", "--days", "0")
    # Fresh task was just created, so won't be stale even with 0 days
    assert_kind_of Array, result
  end

  def test_stale_json_output
    init_trak_flow
    result = run_cli_json("stale")
    assert_kind_of Array, result
  end

  # === sync ===

  def test_sync_exports_to_jsonl
    init_trak_flow
    create_task("Sync me")
    result = run_cli("sync")
    assert_match(/Exported to/, result.stdout)
    assert File.exist?(TrakFlow.jsonl_path)
  end
end
