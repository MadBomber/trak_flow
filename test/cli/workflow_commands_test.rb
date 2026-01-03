# frozen_string_literal: true

require_relative "cli_test_helper"

class WorkflowCommandsTest < Minitest::Test
  include CLITestHelper

  def setup
    setup_temp_trak_flow
    init_trak_flow
  end

  def teardown
    teardown_temp_trak_flow
  end

  def create_workflow(ephemeral: false)
    plan = run_cli_json("plan", "create", "Test Plan")
    run_cli("plan", "add", plan["id"], "Step 1")

    if ephemeral
      run_cli_json("plan", "execute", plan["id"])
    else
      run_cli_json("plan", "start", plan["id"])
    end
  end

  def test_workflow_list_empty
    result = run_cli("workflow", "list")
    assert_match(/No workflows found/, result.stdout)
  end

  def test_workflow_list
    create_workflow
    create_workflow

    result = run_cli("workflow", "list")
    assert_match(/Workflows:/, result.stdout)
  end

  def test_workflow_list_json_output
    create_workflow
    create_workflow

    result = run_cli_json("workflow", "list")
    assert_equal 2, result.size
  end

  def test_workflow_list_ephemeral_only
    create_workflow(ephemeral: false)
    create_workflow(ephemeral: true)

    result = run_cli_json("workflow", "list", "-e")
    assert_equal 1, result.size
    assert_equal true, result.first["ephemeral"]
  end

  def test_workflow_show
    workflow = create_workflow
    result = run_cli("workflow", "show", workflow["id"])
    assert_match(/Workflow: #{workflow["id"]}/, result.stdout)
  end

  def test_workflow_show_json_output
    workflow = create_workflow
    result = run_cli_json("workflow", "show", workflow["id"])
    assert_equal workflow["id"], result["workflow"]["id"]
    assert_kind_of Array, result["tasks"]
  end

  def test_workflow_discard_ephemeral
    workflow = create_workflow(ephemeral: true)
    result = run_cli("workflow", "discard", workflow["id"])
    assert_match(/Discarded Workflow/, result.stdout)
  end

  def test_workflow_discard_json_output
    workflow = create_workflow(ephemeral: true)
    result = run_cli_json("workflow", "discard", workflow["id"])
    assert_equal workflow["id"], result["discarded"]
  end

  def test_workflow_summarize
    workflow = create_workflow
    result = run_cli("workflow", "summarize", workflow["id"], "-s", "Done!")
    assert_match(/Summarized Workflow/, result.stdout)

    # Verify it's closed
    updated = run_cli_json("show", workflow["id"])
    assert_equal "closed", updated["task"]["status"]
  end

  def test_workflow_summarize_json_output
    workflow = create_workflow
    result = run_cli_json("workflow", "summarize", workflow["id"], "-s", "Summary text")
    assert_equal workflow["id"], result["id"]
    assert_equal "closed", result["status"]
  end

  def test_workflow_gc
    # Create an ephemeral workflow (it won't be old enough to collect, but tests the command)
    create_workflow(ephemeral: true)
    result = run_cli("workflow", "gc", "--age", "24h")
    assert_match(/Collected \d+ ephemeral Workflow/, result.stdout)
  end

  def test_workflow_gc_json_output
    result = run_cli_json("workflow", "gc")
    assert result.key?("collected")
  end
end
