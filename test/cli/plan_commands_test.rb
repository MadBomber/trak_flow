# frozen_string_literal: true

require_relative "cli_test_helper"

class PlanCommandsTest < Minitest::Test
  include CLITestHelper

  def setup
    setup_temp_trak_flow
    init_trak_flow
  end

  def teardown
    teardown_temp_trak_flow
  end

  def test_plan_create
    result = run_cli("plan", "create", "My Plan")
    assert_match(/Created Plan:/, result.stdout)
    assert_match(/My Plan/, result.stdout)
  end

  def test_plan_create_json_output
    result = run_cli_json("plan", "create", "My Plan")
    assert result["id"]
    assert_equal "My Plan", result["title"]
    assert_equal true, result["plan"]
  end

  def test_plan_create_with_options
    result = run_cli_json("plan", "create", "Complex Plan", "-d", "Description", "-t", "epic", "-p", "1")
    assert_equal "Complex Plan", result["title"]
    assert_equal "Description", result["description"]
    assert_equal "epic", result["type"]
    assert_equal 1, result["priority"]
    assert_equal true, result["plan"]
  end

  def test_plan_list_empty
    result = run_cli("plan", "list")
    assert_match(/No plans found/, result.stdout)
  end

  def test_plan_list
    run_cli("plan", "create", "Plan 1")
    run_cli("plan", "create", "Plan 2")

    result = run_cli("plan", "list")
    assert_match(/Plans:/, result.stdout)
    assert_match(/Plan 1/, result.stdout)
    assert_match(/Plan 2/, result.stdout)
  end

  def test_plan_list_json_output
    run_cli("plan", "create", "Plan 1")
    run_cli("plan", "create", "Plan 2")

    result = run_cli_json("plan", "list")
    assert_equal 2, result.size
    assert result.all? { |p| p["plan"] == true }
  end

  def test_plan_show
    plan = run_cli_json("plan", "create", "My Plan")
    result = run_cli("plan", "show", plan["id"])
    assert_match(/Plan: #{plan["id"]}/, result.stdout)
    assert_match(/My Plan/, result.stdout)
  end

  def test_plan_show_json_output
    plan = run_cli_json("plan", "create", "My Plan")
    result = run_cli_json("plan", "show", plan["id"])
    assert_equal plan["id"], result["plan"]["id"]
    assert_equal "My Plan", result["plan"]["title"]
    assert_kind_of Array, result["tasks"]
  end

  def test_plan_add_task
    plan = run_cli_json("plan", "create", "My Plan")
    result = run_cli("plan", "add", plan["id"], "Step 1")
    assert_match(/Added Task to Plan/, result.stdout)
    assert_match(/Step 1/, result.stdout)
  end

  def test_plan_add_task_json_output
    plan = run_cli_json("plan", "create", "My Plan")
    result = run_cli_json("plan", "add", plan["id"], "Step 1")
    assert result["id"]
    assert_equal "Step 1", result["title"]
    assert_equal plan["id"], result["parent_id"]
  end

  def test_plan_show_with_tasks
    plan = run_cli_json("plan", "create", "My Plan")
    run_cli("plan", "add", plan["id"], "Step 1")
    run_cli("plan", "add", plan["id"], "Step 2")

    result = run_cli_json("plan", "show", plan["id"])
    assert_equal 2, result["tasks"].size
  end

  def test_plan_start_creates_persistent_workflow
    plan = run_cli_json("plan", "create", "My Plan")
    run_cli("plan", "add", plan["id"], "Step 1")

    result = run_cli("plan", "start", plan["id"])
    assert_match(/Created persistent Workflow/, result.stdout)
  end

  def test_plan_start_json_output
    plan = run_cli_json("plan", "create", "My Plan")
    result = run_cli_json("plan", "start", plan["id"])
    assert result["id"]
    assert_equal plan["id"], result["source_plan_id"]
    assert_equal false, result["ephemeral"]
  end

  def test_plan_execute_creates_ephemeral_workflow
    plan = run_cli_json("plan", "create", "My Plan")
    result = run_cli("plan", "execute", plan["id"])
    assert_match(/Created ephemeral Workflow/, result.stdout)
  end

  def test_plan_execute_json_output
    plan = run_cli_json("plan", "create", "My Plan")
    result = run_cli_json("plan", "execute", plan["id"])
    assert result["id"]
    assert_equal plan["id"], result["source_plan_id"]
    assert_equal true, result["ephemeral"]
  end

  def test_plan_convert
    task_id = create_task("Convert me")
    result = run_cli("plan", "convert", task_id)
    assert_match(/Converted to Plan/, result.stdout)

    task = run_cli_json("show", task_id)
    assert_equal true, task["task"]["plan"]
  end

  def test_plan_convert_json_output
    task_id = create_task("Convert me")
    result = run_cli_json("plan", "convert", task_id)
    assert_equal task_id, result["id"]
    assert_equal true, result["plan"]
  end
end
