# frozen_string_literal: true

require_relative "mcp_test_helper"

class MCPResourcesTest < Minitest::Test
  include MCPTestHelper

  def setup
    setup_mcp_test
  end

  def teardown
    teardown_mcp_test
  end

  # TaskList tests
  def test_task_list_empty
    resource = TrakFlow::Mcp::Resources::TaskList.new
    content = Oj.load(resource.content, symbol_keys: true)

    assert_equal [], content
  end

  def test_task_list_with_tasks
    create_test_task("Task 1")
    create_test_task("Task 2")

    resource = TrakFlow::Mcp::Resources::TaskList.new
    content = Oj.load(resource.content, symbol_keys: true)

    assert_equal 2, content.size
  end

  # TaskById tests
  def test_task_by_id
    task = create_test_task("Test task", description: "A description")

    resource = TrakFlow::Mcp::Resources::TaskById.new
    resource.instance_variable_set(:@params, { id: task.id })
    content = Oj.load(resource.content, symbol_keys: true)

    assert_equal task.id, content[:task][:id]
    assert_equal "Test task", content[:task][:title]
    assert_kind_of Array, content[:labels]
    assert_kind_of Array, content[:dependencies]
    assert_kind_of Array, content[:comments]
  end

  def test_task_by_id_with_labels
    task = create_test_task("Labeled task")
    @db.add_label(TrakFlow::Models::Label.new(task_id: task.id, name: "important"))

    resource = TrakFlow::Mcp::Resources::TaskById.new
    resource.instance_variable_set(:@params, { id: task.id })
    content = Oj.load(resource.content, symbol_keys: true)

    assert_includes content[:labels], "important"
  end

  # TaskNext tests
  def test_task_next_when_no_tasks
    resource = TrakFlow::Mcp::Resources::TaskNext.new
    content = Oj.load(resource.content, symbol_keys: true)

    assert_nil content[:task]
    assert_equal "No ready tasks found", content[:message]
  end

  def test_task_next_returns_highest_priority
    create_test_task("Low priority", priority: 3)
    high = create_test_task("High priority", priority: 1)

    resource = TrakFlow::Mcp::Resources::TaskNext.new
    content = Oj.load(resource.content, symbol_keys: true)

    assert_equal high.id, content[:task][:id]
  end

  # PlanList tests
  def test_plan_list_empty
    resource = TrakFlow::Mcp::Resources::PlanList.new
    content = Oj.load(resource.content, symbol_keys: true)

    assert_equal [], content
  end

  def test_plan_list_with_plans
    create_test_plan("Plan 1")
    create_test_plan("Plan 2")
    create_test_task("Regular task")

    resource = TrakFlow::Mcp::Resources::PlanList.new
    content = Oj.load(resource.content, symbol_keys: true)

    assert_equal 2, content.size
    assert content.all? { |p| p[:plan] == true }
  end

  # PlanById tests
  def test_plan_by_id
    plan = create_test_plan("Deploy workflow")
    @db.create_child_task(plan.id, { title: "Step 1", type: "task", priority: 2 })

    resource = TrakFlow::Mcp::Resources::PlanById.new
    resource.instance_variable_set(:@params, { id: plan.id })
    content = Oj.load(resource.content, symbol_keys: true)

    assert_equal plan.id, content[:plan][:id]
    assert_equal 1, content[:steps].size
    assert_equal "Step 1", content[:steps].first[:title]
  end

  # WorkflowList tests
  def test_workflow_list_empty
    resource = TrakFlow::Mcp::Resources::WorkflowList.new
    content = Oj.load(resource.content, symbol_keys: true)

    assert_equal [], content
  end

  def test_workflow_list_with_workflows
    plan = create_test_plan("Workflow template")

    start_tool = TrakFlow::Mcp::Tools::PlanStart.new
    start_tool.call(plan_id: plan.id)
    start_tool.call(plan_id: plan.id)

    resource = TrakFlow::Mcp::Resources::WorkflowList.new
    content = Oj.load(resource.content, symbol_keys: true)

    assert_equal 2, content.size
    assert content.all? { |w| w[:source_plan_id] == plan.id }
  end

  # WorkflowById tests
  def test_workflow_by_id
    plan = create_test_plan("Workflow")
    @db.create_child_task(plan.id, { title: "Step 1", type: "task", priority: 2 })

    start_tool = TrakFlow::Mcp::Tools::PlanStart.new
    workflow = start_tool.call(plan_id: plan.id)

    resource = TrakFlow::Mcp::Resources::WorkflowById.new
    resource.instance_variable_set(:@params, { id: workflow[:id] })
    content = Oj.load(resource.content, symbol_keys: true)

    assert_equal workflow[:id], content[:workflow][:id]
    assert_equal 1, content[:tasks].size
  end

  # LabelList tests
  def test_label_list_empty
    resource = TrakFlow::Mcp::Resources::LabelList.new
    content = Oj.load(resource.content, symbol_keys: true)

    assert_equal [], content
  end

  def test_label_list_with_labels
    task1 = create_test_task("Task 1")
    task2 = create_test_task("Task 2")
    @db.add_label(TrakFlow::Models::Label.new(task_id: task1.id, name: "urgent"))
    @db.add_label(TrakFlow::Models::Label.new(task_id: task2.id, name: "backend"))
    @db.add_label(TrakFlow::Models::Label.new(task_id: task2.id, name: "urgent"))

    resource = TrakFlow::Mcp::Resources::LabelList.new
    content = Oj.load(resource.content, symbol_keys: true)

    assert_includes content, "urgent"
    assert_includes content, "backend"
  end

  # DependencyGraph tests
  def test_dependency_graph_empty
    resource = TrakFlow::Mcp::Resources::DependencyGraph.new
    content = Oj.load(resource.content, symbol_keys: true)

    assert_equal [], content[:nodes]
    assert_equal [], content[:edges]
  end

  def test_dependency_graph_with_dependencies
    task1 = create_test_task("Task 1")
    task2 = create_test_task("Task 2")
    @db.add_dependency(TrakFlow::Models::Dependency.new(
      source_id: task1.id,
      target_id: task2.id,
      type: "blocks"
    ))

    resource = TrakFlow::Mcp::Resources::DependencyGraph.new
    content = Oj.load(resource.content, symbol_keys: true)

    assert_equal 2, content[:nodes].size
    assert_equal 1, content[:edges].size
    assert_equal task1.id, content[:edges].first[:source]
    assert_equal task2.id, content[:edges].first[:target]
  end
end
