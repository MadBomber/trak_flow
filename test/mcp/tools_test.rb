# frozen_string_literal: true

require_relative "mcp_test_helper"

class MCPToolsTest < Minitest::Test
  include MCPTestHelper

  def setup
    setup_mcp_test
  end

  def teardown
    teardown_mcp_test
  end

  # TaskCreate tests
  def test_task_create_basic
    tool = TrakFlow::Mcp::Tools::TaskCreate.new
    result = tool.call(title: "Test task")

    assert_equal "Test task", result[:title]
    assert_equal "task", result[:type]
    assert_equal 2, result[:priority]
    assert_equal "open", result[:status]
  end

  def test_task_create_with_options
    tool = TrakFlow::Mcp::Tools::TaskCreate.new
    result = tool.call(
      title: "Bug fix",
      type: "bug",
      priority: 1,
      description: "Fix the issue",
      assignee: "robot"
    )

    assert_equal "Bug fix", result[:title]
    assert_equal "bug", result[:type]
    assert_equal 1, result[:priority]
    assert_equal "Fix the issue", result[:description]
    assert_equal "robot", result[:assignee]
  end

  def test_task_create_with_parent
    parent = create_test_task("Parent task")

    tool = TrakFlow::Mcp::Tools::TaskCreate.new
    result = tool.call(title: "Child task", parent_id: parent.id)

    assert_equal "Child task", result[:title]
    assert_equal parent.id, result[:parent_id]
  end

  def test_task_create_with_labels
    tool = TrakFlow::Mcp::Tools::TaskCreate.new
    result = tool.call(title: "Labeled task", labels: ["urgent", "backend"])

    task = @db.find_task(result[:id])
    labels = @db.find_labels(task.id).map(&:name)

    assert_includes labels, "urgent"
    assert_includes labels, "backend"
  end

  # TaskUpdate tests
  def test_task_update_title
    task = create_test_task("Original title")

    tool = TrakFlow::Mcp::Tools::TaskUpdate.new
    result = tool.call(id: task.id, title: "Updated title")

    assert_equal "Updated title", result[:title]
  end

  def test_task_update_status
    task = create_test_task("Task")

    tool = TrakFlow::Mcp::Tools::TaskUpdate.new
    result = tool.call(id: task.id, status: "in_progress")

    assert_equal "in_progress", result[:status]
  end

  def test_task_update_priority
    task = create_test_task("Task")

    tool = TrakFlow::Mcp::Tools::TaskUpdate.new
    result = tool.call(id: task.id, priority: 0)

    assert_equal 0, result[:priority]
  end

  # TaskClose tests
  def test_task_close
    task = create_test_task("Task to close")

    tool = TrakFlow::Mcp::Tools::TaskClose.new
    result = tool.call(id: task.id)

    assert_equal "closed", result[:status]
    refute_nil result[:closed_at]
  end

  def test_task_close_with_reason
    task = create_test_task("Task")

    tool = TrakFlow::Mcp::Tools::TaskClose.new
    result = tool.call(id: task.id, reason: "completed")

    assert_equal "closed", result[:status]
  end

  # TaskStart tests
  def test_task_start
    task = create_test_task("Task to start")

    tool = TrakFlow::Mcp::Tools::TaskStart.new
    result = tool.call(id: task.id)

    assert_equal "in_progress", result[:status]
  end

  # TaskBlock tests
  def test_task_block
    task = create_test_task("Task to block")

    tool = TrakFlow::Mcp::Tools::TaskBlock.new
    result = tool.call(id: task.id)

    assert_equal "blocked", result[:status]
  end

  def test_task_block_with_reason
    task = create_test_task("Task")

    tool = TrakFlow::Mcp::Tools::TaskBlock.new
    result = tool.call(id: task.id, reason: "waiting for API")

    assert_equal "blocked", result[:status]
    assert_includes result[:notes], "[BLOCKED]"
    assert_includes result[:notes], "waiting for API"
  end

  # TaskDefer tests
  def test_task_defer
    task = create_test_task("Task to defer")

    tool = TrakFlow::Mcp::Tools::TaskDefer.new
    result = tool.call(id: task.id)

    assert_equal "deferred", result[:status]
  end

  # PlanCreate tests
  def test_plan_create
    tool = TrakFlow::Mcp::Tools::PlanCreate.new
    result = tool.call(title: "Deploy workflow")

    assert_equal "Deploy workflow", result[:title]
    assert_equal true, result[:plan]
  end

  def test_plan_create_with_description
    tool = TrakFlow::Mcp::Tools::PlanCreate.new
    result = tool.call(
      title: "Build pipeline",
      description: "Standard build process"
    )

    assert_equal "Standard build process", result[:description]
    assert_equal true, result[:plan]
  end

  # PlanAddStep tests
  def test_plan_add_step
    plan = create_test_plan("Deploy workflow")

    tool = TrakFlow::Mcp::Tools::PlanAddStep.new
    result = tool.call(plan_id: plan.id, title: "Step 1: Build")

    assert_equal "Step 1: Build", result[:title]
    assert_equal plan.id, result[:parent_id]
  end

  def test_plan_add_step_fails_for_non_plan
    task = create_test_task("Regular task")

    tool = TrakFlow::Mcp::Tools::PlanAddStep.new
    assert_raises(TrakFlow::Error) do
      tool.call(plan_id: task.id, title: "Step")
    end
  end

  # PlanStart tests
  def test_plan_start_creates_workflow
    plan = create_test_plan("Deploy workflow")

    tool = TrakFlow::Mcp::Tools::PlanStart.new
    result = tool.call(plan_id: plan.id)

    assert_equal plan.id, result[:source_plan_id]
    assert_equal false, result[:ephemeral]
  end

  def test_plan_start_copies_steps
    plan = create_test_plan("Workflow")
    @db.create_child_task(plan.id, { title: "Step 1", type: "task", priority: 2 })
    @db.create_child_task(plan.id, { title: "Step 2", type: "task", priority: 2 })

    tool = TrakFlow::Mcp::Tools::PlanStart.new
    result = tool.call(plan_id: plan.id)

    workflow_tasks = @db.child_tasks(result[:id])
    assert_equal 2, workflow_tasks.size
  end

  def test_plan_start_with_variables
    plan = create_test_plan("Deploy {{env}}")

    tool = TrakFlow::Mcp::Tools::PlanStart.new
    result = tool.call(plan_id: plan.id, variables: { "env" => "production" })

    assert_equal "Deploy production", result[:title]
  end

  # PlanRun tests
  def test_plan_run_creates_ephemeral_workflow
    plan = create_test_plan("Quick task")

    tool = TrakFlow::Mcp::Tools::PlanRun.new
    result = tool.call(plan_id: plan.id)

    assert_equal plan.id, result[:source_plan_id]
    assert_equal true, result[:ephemeral]
  end

  # WorkflowDiscard tests
  def test_workflow_discard
    plan = create_test_plan("Workflow")
    run_tool = TrakFlow::Mcp::Tools::PlanRun.new
    workflow = run_tool.call(plan_id: plan.id)

    discard_tool = TrakFlow::Mcp::Tools::WorkflowDiscard.new
    result = discard_tool.call(id: workflow[:id])

    assert_equal workflow[:id], result[:discarded]
    assert_nil @db.find_task(workflow[:id])
  end

  def test_workflow_discard_fails_for_non_ephemeral
    plan = create_test_plan("Workflow")
    start_tool = TrakFlow::Mcp::Tools::PlanStart.new
    workflow = start_tool.call(plan_id: plan.id)

    discard_tool = TrakFlow::Mcp::Tools::WorkflowDiscard.new
    assert_raises(TrakFlow::Error) do
      discard_tool.call(id: workflow[:id])
    end
  end

  # WorkflowSummarize tests
  def test_workflow_summarize
    plan = create_test_plan("Workflow")
    start_tool = TrakFlow::Mcp::Tools::PlanStart.new
    workflow = start_tool.call(plan_id: plan.id)

    summarize_tool = TrakFlow::Mcp::Tools::WorkflowSummarize.new
    result = summarize_tool.call(id: workflow[:id], summary: "Completed successfully")

    assert_equal "closed", result[:status]
    assert_includes result[:notes], "[Summary]"
    assert_includes result[:notes], "Completed successfully"
  end

  # DepAdd tests
  def test_dep_add
    task1 = create_test_task("Task 1")
    task2 = create_test_task("Task 2")

    tool = TrakFlow::Mcp::Tools::DepAdd.new
    result = tool.call(source_id: task1.id, target_id: task2.id)

    assert_equal task1.id, result[:source_id]
    assert_equal task2.id, result[:target_id]
    assert_equal "blocks", result[:type]
  end

  def test_dep_add_with_type
    task1 = create_test_task("Task 1")
    task2 = create_test_task("Task 2")

    tool = TrakFlow::Mcp::Tools::DepAdd.new
    result = tool.call(source_id: task1.id, target_id: task2.id, type: "related")

    assert_equal "related", result[:type]
  end

  # DepRemove tests
  def test_dep_remove
    task1 = create_test_task("Task 1")
    task2 = create_test_task("Task 2")

    add_tool = TrakFlow::Mcp::Tools::DepAdd.new
    add_tool.call(source_id: task1.id, target_id: task2.id)

    remove_tool = TrakFlow::Mcp::Tools::DepRemove.new
    result = remove_tool.call(source_id: task1.id, target_id: task2.id)

    assert_equal true, result[:removed]
  end

  # LabelAdd tests
  def test_label_add
    task = create_test_task("Task")

    tool = TrakFlow::Mcp::Tools::LabelAdd.new
    result = tool.call(task_id: task.id, name: "urgent")

    assert_equal "urgent", result[:label]

    labels = @db.find_labels(task.id).map(&:name)
    assert_includes labels, "urgent"
  end

  # LabelRemove tests
  def test_label_remove
    task = create_test_task("Task")
    @db.add_label(TrakFlow::Models::Label.new(task_id: task.id, name: "temp"))

    tool = TrakFlow::Mcp::Tools::LabelRemove.new
    result = tool.call(task_id: task.id, name: "temp")

    assert_equal true, result[:removed]

    labels = @db.find_labels(task.id).map(&:name)
    refute_includes labels, "temp"
  end

  # CommentAdd tests
  def test_comment_add
    task = create_test_task("Task")

    tool = TrakFlow::Mcp::Tools::CommentAdd.new
    result = tool.call(task_id: task.id, body: "This is a comment")

    assert_equal "This is a comment", result[:body]
    assert_equal "robot", result[:author]
  end

  def test_comment_add_with_author
    task = create_test_task("Task")

    tool = TrakFlow::Mcp::Tools::CommentAdd.new
    result = tool.call(task_id: task.id, body: "Comment", author: "claude")

    assert_equal "claude", result[:author]
  end
end
