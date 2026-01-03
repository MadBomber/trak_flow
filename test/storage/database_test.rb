# frozen_string_literal: true

require_relative "../test_helper"

class DatabaseTest < Minitest::Test
  include TrakFlowTestHelper

  def setup
    super
    @db = init_trak_flow
  end

  def teardown
    @db&.close
    super
  end

  # Task operations

  def test_create_task_generates_id
    task = TrakFlow::Models::Task.new(title: "Test Task")
    created = @db.create_task(task)

    assert_match(/^tf-[a-f0-9]+$/, created.id)
    assert_equal "Test Task", created.title
    refute_nil created.content_hash
  end

  def test_create_task_marks_database_dirty
    task = TrakFlow::Models::Task.new(title: "Test Task")
    @db.create_task(task)

    assert @db.dirty?
  end

  def test_find_task_returns_nil_for_nonexistent
    assert_nil @db.find_task("tf-nonexistent")
  end

  def test_find_task_finds_existing_task
    task = TrakFlow::Models::Task.new(title: "Test")
    created = @db.create_task(task)

    found = @db.find_task(created.id)

    assert_equal "Test", found.title
  end

  def test_find_task_bang_raises_for_nonexistent
    assert_raises(TrakFlow::TaskNotFoundError) do
      @db.find_task!("tf-nonexistent")
    end
  end

  def test_update_task
    task = TrakFlow::Models::Task.new(title: "Test")
    created = @db.create_task(task)

    created.title = "Updated"
    @db.update_task(created)

    found = @db.find_task(created.id)

    assert_equal "Updated", found.title
  end

  def test_delete_task
    task = TrakFlow::Models::Task.new(title: "Test")
    created = @db.create_task(task)

    @db.delete_task(created.id)

    assert_nil @db.find_task(created.id)
  end

  def test_list_tasks_returns_all
    @db.create_task(TrakFlow::Models::Task.new(title: "Open 1", status: "open", priority: 1))
    @db.create_task(TrakFlow::Models::Task.new(title: "Open 2", status: "open", priority: 2))
    @db.create_task(TrakFlow::Models::Task.new(title: "Closed", status: "closed"))

    tasks = @db.list_tasks

    assert_equal 3, tasks.size
  end

  def test_list_tasks_filters_by_status
    @db.create_task(TrakFlow::Models::Task.new(title: "Open 1", status: "open"))
    @db.create_task(TrakFlow::Models::Task.new(title: "Open 2", status: "open"))
    @db.create_task(TrakFlow::Models::Task.new(title: "Closed", status: "closed"))

    tasks = @db.list_tasks(status: "open")

    assert_equal 2, tasks.size
  end

  def test_list_tasks_filters_by_priority
    @db.create_task(TrakFlow::Models::Task.new(title: "P1", priority: 1))
    @db.create_task(TrakFlow::Models::Task.new(title: "P2", priority: 2))

    tasks = @db.list_tasks(priority: 1)

    assert_equal 1, tasks.size
    assert_equal "P1", tasks.first.title
  end

  # Dependency operations

  def test_ready_tasks_returns_tasks_without_blockers
    task1 = @db.create_task(TrakFlow::Models::Task.new(title: "Task 1"))
    task2 = @db.create_task(TrakFlow::Models::Task.new(title: "Task 2"))

    dep = TrakFlow::Models::Dependency.new(
      source_id: task1.id,
      target_id: task2.id,
      type: "blocks"
    )
    @db.add_dependency(dep)

    ready = @db.ready_tasks
    ready_ids = ready.map(&:id)

    assert_includes ready_ids, task1.id
    refute_includes ready_ids, task2.id
  end

  def test_add_dependency_creates_dependency
    task1 = @db.create_task(TrakFlow::Models::Task.new(title: "Task 1"))
    task2 = @db.create_task(TrakFlow::Models::Task.new(title: "Task 2"))

    dep = TrakFlow::Models::Dependency.new(
      source_id: task1.id,
      target_id: task2.id,
      type: "blocks"
    )
    @db.add_dependency(dep)

    deps = @db.find_dependencies(task2.id, direction: :incoming)

    assert_equal 1, deps.size
    assert_equal task1.id, deps.first.source_id
  end

  def test_add_dependency_detects_cycles
    task1 = @db.create_task(TrakFlow::Models::Task.new(title: "Task 1"))
    task2 = @db.create_task(TrakFlow::Models::Task.new(title: "Task 2"))

    dep1 = TrakFlow::Models::Dependency.new(
      source_id: task1.id,
      target_id: task2.id,
      type: "blocks"
    )
    @db.add_dependency(dep1)

    dep2 = TrakFlow::Models::Dependency.new(
      source_id: task2.id,
      target_id: task1.id,
      type: "blocks"
    )

    assert_raises(TrakFlow::DependencyCycleError) do
      @db.add_dependency(dep2)
    end
  end

  # Label operations

  def test_add_label
    task = @db.create_task(TrakFlow::Models::Task.new(title: "Test"))
    label = TrakFlow::Models::Label.new(task_id: task.id, name: "bug")

    @db.add_label(label)

    labels = @db.find_labels(task.id)

    assert_includes labels.map(&:name), "bug"
  end

  def test_add_label_ignores_duplicates
    task = @db.create_task(TrakFlow::Models::Task.new(title: "Test"))
    label1 = TrakFlow::Models::Label.new(task_id: task.id, name: "bug")
    label2 = TrakFlow::Models::Label.new(task_id: task.id, name: "bug")

    @db.add_label(label1)
    @db.add_label(label2)

    labels = @db.find_labels(task.id)

    assert_equal 1, labels.size
  end

  # State operations

  def test_set_and_get_state
    task = @db.create_task(TrakFlow::Models::Task.new(title: "Test"))

    @db.set_state(task.id, "mode", "normal")

    assert_equal "normal", @db.get_state(task.id, "mode")

    @db.set_state(task.id, "mode", "muted")

    assert_equal "muted", @db.get_state(task.id, "mode")

    labels = @db.find_labels(task.id)
    mode_labels = labels.select { |l| l.name.start_with?("mode:") }

    assert_equal 1, mode_labels.size
  end

  # Child task operations

  def test_create_child_task
    parent = @db.create_task(TrakFlow::Models::Task.new(title: "Epic", type: "epic"))
    child = @db.create_child_task(parent.id, { title: "Sub-task" })

    assert_equal "#{parent.id}.1", child.id
    assert_equal parent.id, child.parent_id

    deps = @db.find_dependencies(child.id, direction: :incoming)

    assert deps.any? { |d| d.type == "parent-child" }
  end

  # Stale task operations

  def test_stale_tasks
    old_task = TrakFlow::Models::Task.new(title: "Old")
    old_task.updated_at = Time.now.utc - (60 * 24 * 60 * 60)
    @db.create_task(old_task)

    @db.create_task(TrakFlow::Models::Task.new(title: "New"))

    stale = @db.stale_tasks(days: 30)

    assert_equal 1, stale.size
    assert_equal "Old", stale.first.title
  end

  # Plan operations

  def test_find_plans_returns_only_plans
    @db.create_task(TrakFlow::Models::Task.new(title: "Plan 1", plan: true))
    @db.create_task(TrakFlow::Models::Task.new(title: "Plan 2", plan: true))
    @db.create_task(TrakFlow::Models::Task.new(title: "Regular Task"))

    plans = @db.find_plans

    assert_equal 2, plans.size
    assert plans.all?(&:plan?)
  end

  def test_find_plan_tasks_returns_child_tasks
    plan = @db.create_task(TrakFlow::Models::Task.new(title: "My Plan", plan: true))
    @db.create_child_task(plan.id, { title: "Step 1" })
    @db.create_child_task(plan.id, { title: "Step 2" })

    tasks = @db.find_plan_tasks(plan.id)

    assert_equal 2, tasks.size
    assert_equal plan.id, tasks.first.parent_id
  end

  def test_mark_as_plan_converts_task_to_plan
    task = @db.create_task(TrakFlow::Models::Task.new(title: "To Be Plan"))

    refute task.plan?

    @db.mark_as_plan(task.id)

    updated = @db.find_task(task.id)

    assert updated.plan?
    assert_equal "open", updated.status
    refute updated.ephemeral?
  end

  # Workflow operations

  def test_find_workflows_returns_only_workflows
    plan = @db.create_task(TrakFlow::Models::Task.new(title: "Plan", plan: true))
    @db.create_task(TrakFlow::Models::Task.new(title: "Workflow 1", source_plan_id: plan.id))
    @db.create_task(TrakFlow::Models::Task.new(title: "Workflow 2", source_plan_id: plan.id))
    @db.create_task(TrakFlow::Models::Task.new(title: "Regular Task"))

    workflows = @db.find_workflows

    assert_equal 2, workflows.size
    assert workflows.all?(&:workflow?)
  end

  def test_find_workflows_filters_by_plan_id
    plan1 = @db.create_task(TrakFlow::Models::Task.new(title: "Plan 1", plan: true))
    plan2 = @db.create_task(TrakFlow::Models::Task.new(title: "Plan 2", plan: true))
    @db.create_task(TrakFlow::Models::Task.new(title: "WF from P1", source_plan_id: plan1.id))
    @db.create_task(TrakFlow::Models::Task.new(title: "WF from P2", source_plan_id: plan2.id))

    workflows = @db.find_workflows(plan_id: plan1.id)

    assert_equal 1, workflows.size
    assert_equal plan1.id, workflows.first.source_plan_id
  end

  def test_find_workflow_tasks_returns_child_tasks
    workflow = @db.create_task(TrakFlow::Models::Task.new(title: "Workflow", source_plan_id: "tf-plan"))
    @db.create_child_task(workflow.id, { title: "Work Item 1" })
    @db.create_child_task(workflow.id, { title: "Work Item 2" })

    tasks = @db.find_workflow_tasks(workflow.id)

    assert_equal 2, tasks.size
  end

  # Ephemeral operations (new naming)

  def test_find_ephemeral_workflows
    @db.create_task(TrakFlow::Models::Task.new(title: "Ephemeral 1", ephemeral: true))
    @db.create_task(TrakFlow::Models::Task.new(title: "Ephemeral 2", ephemeral: true))
    @db.create_task(TrakFlow::Models::Task.new(title: "Persistent"))

    ephemeral = @db.find_ephemeral_workflows

    assert_equal 2, ephemeral.size
    assert ephemeral.all?(&:ephemeral?)
  end

  def test_garbage_collect_ephemeral
    old_ephemeral = TrakFlow::Models::Task.new(title: "Old", ephemeral: true)
    old_ephemeral.created_at = Time.now.utc - (48 * 60 * 60)
    @db.create_task(old_ephemeral)

    @db.create_task(TrakFlow::Models::Task.new(title: "New", ephemeral: true))

    count = @db.garbage_collect_ephemeral(max_age_hours: 24)

    assert_equal 1, count
    assert_equal 1, @db.find_ephemeral_workflows.size
  end

  # List tasks filter behavior

  def test_list_tasks_excludes_plans_by_default
    @db.create_task(TrakFlow::Models::Task.new(title: "Plan", plan: true))
    @db.create_task(TrakFlow::Models::Task.new(title: "Task"))

    tasks = @db.list_tasks

    assert_equal 1, tasks.size
    refute tasks.first.plan?
  end

  def test_list_tasks_includes_plans_when_requested
    @db.create_task(TrakFlow::Models::Task.new(title: "Plan", plan: true))
    @db.create_task(TrakFlow::Models::Task.new(title: "Task"))

    tasks = @db.list_tasks(include_plans: true)

    assert_equal 2, tasks.size
  end

  def test_list_tasks_excludes_ephemeral_by_default
    @db.create_task(TrakFlow::Models::Task.new(title: "Ephemeral", ephemeral: true))
    @db.create_task(TrakFlow::Models::Task.new(title: "Persistent"))

    tasks = @db.list_tasks

    assert_equal 1, tasks.size
    refute tasks.first.ephemeral?
  end

  def test_list_tasks_includes_ephemeral_when_requested
    @db.create_task(TrakFlow::Models::Task.new(title: "Ephemeral", ephemeral: true))
    @db.create_task(TrakFlow::Models::Task.new(title: "Persistent"))

    tasks = @db.list_tasks(include_ephemeral: true)

    assert_equal 2, tasks.size
  end

  # Ready/blocked tasks exclude plans and ephemeral

  def test_ready_tasks_excludes_plans
    @db.create_task(TrakFlow::Models::Task.new(title: "Plan", plan: true))
    task = @db.create_task(TrakFlow::Models::Task.new(title: "Task"))

    ready = @db.ready_tasks

    assert_equal 1, ready.size
    assert_equal task.id, ready.first.id
  end

  def test_ready_tasks_excludes_ephemeral
    @db.create_task(TrakFlow::Models::Task.new(title: "Ephemeral", ephemeral: true))
    task = @db.create_task(TrakFlow::Models::Task.new(title: "Persistent"))

    ready = @db.ready_tasks

    assert_equal 1, ready.size
    assert_equal task.id, ready.first.id
  end

  def test_stale_tasks_excludes_plans
    old_plan = TrakFlow::Models::Task.new(title: "Old Plan", plan: true)
    old_plan.updated_at = Time.now.utc - (60 * 24 * 60 * 60)
    @db.create_task(old_plan)

    old_task = TrakFlow::Models::Task.new(title: "Old Task")
    old_task.updated_at = Time.now.utc - (60 * 24 * 60 * 60)
    @db.create_task(old_task)

    stale = @db.stale_tasks(days: 30)

    assert_equal 1, stale.size
    assert_equal "Old Task", stale.first.title
  end
end
