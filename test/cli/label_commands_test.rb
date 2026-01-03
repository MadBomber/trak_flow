# frozen_string_literal: true

require_relative "cli_test_helper"

class LabelCommandsTest < Minitest::Test
  include CLITestHelper

  def setup
    setup_temp_trak_flow
    init_trak_flow
  end

  def teardown
    teardown_temp_trak_flow
  end

  def test_label_add
    task_id = create_task("Labeled task")
    result = run_cli("label", "add", task_id, "urgent")
    assert_match(/Added label 'urgent'/, result.stdout)
  end

  def test_label_add_json_output
    task_id = create_task("Labeled task")
    result = run_cli_json("label", "add", task_id, "urgent")
    assert_equal task_id, result["task_id"]
    assert_equal "urgent", result["name"]
  end

  def test_label_remove
    task_id = create_task("Labeled task")
    run_cli("label", "add", task_id, "urgent")

    result = run_cli("label", "remove", task_id, "urgent")
    assert_match(/Removed label 'urgent'/, result.stdout)
  end

  def test_label_remove_json_output
    task_id = create_task("Labeled task")
    run_cli("label", "add", task_id, "urgent")

    result = run_cli_json("label", "remove", task_id, "urgent")
    assert_equal 1, result["removed"]
  end

  def test_label_remove_nonexistent
    task_id = create_task("Unlabeled task")
    result = run_cli("label", "remove", task_id, "nonexistent")
    assert_match(/Label not found/, result.stdout)
  end

  def test_label_list
    task_id = create_task("Labeled task")
    run_cli("label", "add", task_id, "urgent")
    run_cli("label", "add", task_id, "bug")

    result = run_cli("label", "list", task_id)
    assert_match(/urgent/, result.stdout)
    assert_match(/bug/, result.stdout)
  end

  def test_label_list_empty
    task_id = create_task("Unlabeled task")
    result = run_cli("label", "list", task_id)
    assert_match(/No labels/, result.stdout)
  end

  def test_label_list_json_output
    task_id = create_task("Labeled task")
    run_cli("label", "add", task_id, "urgent")
    run_cli("label", "add", task_id, "bug")

    result = run_cli_json("label", "list", task_id)
    assert_equal 2, result.size
    names = result.map { |l| l["name"] }
    assert_includes names, "urgent"
    assert_includes names, "bug"
  end

  def test_label_list_all
    task1_id = create_task("Task 1")
    task2_id = create_task("Task 2")
    run_cli("label", "add", task1_id, "urgent")
    run_cli("label", "add", task2_id, "feature")

    result = run_cli("label", "list-all")
    assert_match(/urgent/, result.stdout)
    assert_match(/feature/, result.stdout)
  end

  def test_label_list_all_empty
    result = run_cli("label", "list-all")
    assert_match(/No labels/, result.stdout)
  end

  def test_label_list_all_json_output
    task_id = create_task("Task 1")
    run_cli("label", "add", task_id, "urgent")
    run_cli("label", "add", task_id, "feature")

    result = run_cli_json("label", "list-all")
    assert_includes result, "urgent"
    assert_includes result, "feature"
  end
end
