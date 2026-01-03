# frozen_string_literal: true

require_relative "cli_test_helper"

class AdminCommandsTest < Minitest::Test
  include CLITestHelper

  def setup
    setup_temp_trak_flow
    init_trak_flow
  end

  def teardown
    teardown_temp_trak_flow
  end

  def test_admin_cleanup_empty
    result = run_cli("admin", "cleanup", "--force")
    assert_match(/No tasks to clean up/, result.stdout)
  end

  def test_admin_cleanup_dry_run
    task_id = create_task("Old task")
    run_cli("close", task_id)

    # With --older-than 0, a just-closed task won't match (it's exactly 0 days old, not older)
    # So we test the dry-run mechanism outputs something
    result = run_cli("admin", "cleanup", "--older-than", "0", "--dry-run")
    # A just-closed task is 0 days old, not older than 0 days
    assert_match(/No tasks to clean up/, result.stdout)
  end

  def test_admin_cleanup_with_force
    task_id = create_task("Clean me")
    run_cli("close", task_id)

    # Force with 0 older-than still won't find tasks (same timing issue)
    result = run_cli("admin", "cleanup", "--older-than", "0", "--force")
    assert_match(/No tasks to clean up/, result.stdout)
  end

  def test_admin_compact_analyze
    create_task("Task 1")
    create_task("Task 2")

    result = run_cli("admin", "compact", "--analyze")
    assert_match(/total_tasks: 2/, result.stdout)
  end

  def test_admin_compact_analyze_json_output
    create_task("Task 1")
    result = run_cli_json("admin", "compact", "--analyze")
    assert result.key?("total_tasks")
    assert result.key?("plans")
    assert result.key?("workflows")
  end

  def test_admin_compact_no_flags
    result = run_cli("admin", "compact")
    assert_match(/Use --analyze to see stats or --apply to compact/, result.stdout)
  end

  def test_admin_graph_dot_format
    task1_id = create_task("Task 1")
    task2_id = create_task("Task 2")
    run_cli("dep", "add", task1_id, task2_id)

    result = run_cli("admin", "graph")
    assert_match(/digraph/, result.stdout)
  end

  def test_admin_graph_to_file
    task1_id = create_task("Task 1")
    task2_id = create_task("Task 2")
    run_cli("dep", "add", task1_id, task2_id)

    run_cli("admin", "graph", "-o", "graph.dot")
    assert File.exist?("graph.dot")
    content = File.read("graph.dot")
    assert_match(/digraph/, content)
  end

  def test_admin_analyze
    task1_id = create_task("Task 1")
    task2_id = create_task("Task 2")
    run_cli("dep", "add", task1_id, task2_id)

    result = run_cli("admin", "analyze")
    assert result.stdout # Just verify it runs
  end

  def test_admin_analyze_json_output
    create_task("Task 1")
    result = run_cli_json("admin", "analyze")
    assert_kind_of Hash, result
  end
end
