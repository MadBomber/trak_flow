# frozen_string_literal: true

require_relative "cli_test_helper"

class DepCommandsTest < Minitest::Test
  include CLITestHelper

  def setup
    setup_temp_trak_flow
    init_trak_flow
  end

  def teardown
    teardown_temp_trak_flow
  end

  def test_dep_add
    task1_id = create_task("Task 1")
    task2_id = create_task("Task 2")

    result = run_cli("dep", "add", task1_id, task2_id)
    assert_match(/Added dependency/, result.stdout)
    assert_match(/blocks/, result.stdout)
  end

  def test_dep_add_with_type
    task1_id = create_task("Task 1")
    task2_id = create_task("Task 2")

    result = run_cli("dep", "add", task1_id, task2_id, "-t", "related")
    assert_match(/Added dependency/, result.stdout)
    assert_match(/related/, result.stdout)
  end

  def test_dep_add_json_output
    task1_id = create_task("Task 1")
    task2_id = create_task("Task 2")

    result = run_cli_json("dep", "add", task1_id, task2_id)
    assert_equal task1_id, result["source_id"]
    assert_equal task2_id, result["target_id"]
    assert_equal "blocks", result["type"]
  end

  def test_dep_remove
    task1_id = create_task("Task 1")
    task2_id = create_task("Task 2")
    run_cli("dep", "add", task1_id, task2_id)

    result = run_cli("dep", "remove", task1_id, task2_id)
    assert_match(/Removed \d+ dependency/, result.stdout)
  end

  def test_dep_remove_json_output
    task1_id = create_task("Task 1")
    task2_id = create_task("Task 2")
    run_cli("dep", "add", task1_id, task2_id)

    result = run_cli_json("dep", "remove", task1_id, task2_id)
    assert_equal 1, result["removed"]
  end

  def test_dep_tree
    task1_id = create_task("Root task")
    task2_id = create_task("Child task")
    run_cli("dep", "add", task1_id, task2_id)

    result = run_cli("dep", "tree", task1_id)
    assert_match(/Root task/, result.stdout)
  end

  def test_dep_tree_json_output
    task1_id = create_task("Root task")
    task2_id = create_task("Child task")
    run_cli("dep", "add", task1_id, task2_id)

    result = run_cli_json("dep", "tree", task1_id)
    assert_equal task1_id, result["id"]
    assert_equal "Root task", result["title"]
  end
end
