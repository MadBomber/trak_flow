# frozen_string_literal: true

require_relative "../test_helper"

class TaskTest < Minitest::Test
  include TrakFlowTestHelper

  def test_initialize_with_default_values
    task = TrakFlow::Models::Task.new(title: "Test Task")

    assert_equal "Test Task", task.title
    assert_equal "open", task.status
    assert_equal 2, task.priority
    assert_equal "task", task.type
    refute task.ephemeral
  end

  def test_initialize_accepts_all_attributes
    task = TrakFlow::Models::Task.new(
      id: "tf-test",
      title: "Test",
      description: "Description",
      status: "in_progress",
      priority: 1,
      type: "feature",
      assignee: "user",
      parent_id: "tf-parent"
    )

    assert_equal "tf-test", task.id
    assert_equal "in_progress", task.status
    assert_equal 1, task.priority
    assert_equal "feature", task.type
    assert_equal "user", task.assignee
    assert_equal "tf-parent", task.parent_id
  end

  def test_valid_with_title
    task = TrakFlow::Models::Task.new(title: "Test")

    assert task.valid?
  end

  def test_invalid_without_title
    task = TrakFlow::Models::Task.new

    refute task.valid?
    assert_includes task.errors, "Title is required"
  end

  def test_invalid_with_invalid_status
    task = TrakFlow::Models::Task.new(title: "Test", status: "invalid")

    refute task.valid?
    assert task.errors.first.match?(/Invalid status/)
  end

  def test_invalid_with_invalid_priority
    task = TrakFlow::Models::Task.new(title: "Test", priority: 99)

    refute task.valid?
    assert task.errors.first.match?(/Invalid priority/)
  end

  def test_invalid_with_invalid_type
    task = TrakFlow::Models::Task.new(title: "Test", type: "invalid")

    refute task.valid?
    assert task.errors.first.match?(/Invalid type/)
  end

  def test_close_marks_task_as_closed
    task = TrakFlow::Models::Task.new(title: "Test")
    task.close!(reason: "Done")

    assert_equal "closed", task.status
    refute_nil task.closed_at
    assert_includes task.notes, "[Closed] Done"
  end

  def test_reopen_reopens_closed_task
    task = TrakFlow::Models::Task.new(title: "Test", status: "closed")
    task.reopen!(reason: "Not done")

    assert_equal "open", task.status
    assert_nil task.closed_at
    assert_includes task.notes, "[Reopened] Not done"
  end

  def test_to_h_serializes_task
    task = TrakFlow::Models::Task.new(
      id: "tf-test",
      title: "Test",
      description: "Desc",
      status: "open",
      priority: 2,
      type: "task"
    )

    hash = task.to_h

    assert_equal "tf-test", hash[:id]
    assert_equal "Test", hash[:title]
    assert_equal "Desc", hash[:description]
    assert_equal "open", hash[:status]
    assert_equal 2, hash[:priority]
    assert_equal "task", hash[:type]
  end

  def test_from_hash_deserializes_task
    hash = {
      id: "tf-test",
      title: "Test",
      description: "Desc",
      status: "open",
      priority: 2,
      type: "task",
      created_at: "2024-01-01T00:00:00Z"
    }

    task = TrakFlow::Models::Task.from_hash(hash)

    assert_equal "tf-test", task.id
    assert_equal "Test", task.title
    assert_instance_of Time, task.created_at
  end

  def test_open_predicate
    task = TrakFlow::Models::Task.new(title: "T", status: "open")

    assert task.open?
  end

  def test_closed_predicate
    task = TrakFlow::Models::Task.new(title: "T", status: "closed")

    assert task.closed?
  end

  def test_in_progress_predicate
    task = TrakFlow::Models::Task.new(title: "T", status: "in_progress")

    assert task.in_progress?
  end

  def test_blocked_predicate
    task = TrakFlow::Models::Task.new(title: "T", status: "blocked")

    assert task.blocked?
  end

  def test_epic_predicate
    epic = TrakFlow::Models::Task.new(title: "T", type: "epic")
    task = TrakFlow::Models::Task.new(title: "T", type: "task")

    assert epic.epic?
    refute task.epic?
  end

  # Plan/Workflow predicates

  def test_plan_predicate
    plan = TrakFlow::Models::Task.new(title: "Plan", plan: true)
    task = TrakFlow::Models::Task.new(title: "Task", plan: false)

    assert plan.plan?
    refute task.plan?
  end

  def test_workflow_predicate
    workflow = TrakFlow::Models::Task.new(title: "Workflow", source_plan_id: "tf-plan-1")
    plan = TrakFlow::Models::Task.new(title: "Plan", plan: true)
    task = TrakFlow::Models::Task.new(title: "Task")

    assert workflow.workflow?
    refute plan.workflow?
    refute task.workflow?
  end

  def test_ephemeral_predicate
    ephemeral = TrakFlow::Models::Task.new(title: "T", ephemeral: true)
    normal = TrakFlow::Models::Task.new(title: "T", ephemeral: false)

    assert ephemeral.ephemeral?
    refute normal.ephemeral?
  end

  def test_executable_predicate
    plan = TrakFlow::Models::Task.new(title: "Plan", plan: true)
    task = TrakFlow::Models::Task.new(title: "Task")

    refute plan.executable?
    assert task.executable?
  end

  def test_discardable_predicate
    ephemeral = TrakFlow::Models::Task.new(title: "T", ephemeral: true)
    persistent = TrakFlow::Models::Task.new(title: "T", ephemeral: false)

    assert ephemeral.discardable?
    refute persistent.discardable?
  end

  # Validation rules for Plans

  def test_invalid_plan_cannot_be_ephemeral
    task = TrakFlow::Models::Task.new(title: "T", plan: true, ephemeral: true)

    refute task.valid?
    assert_includes task.errors, "Plans cannot be ephemeral"
  end

  def test_invalid_plan_cannot_change_status
    task = TrakFlow::Models::Task.new(title: "T", plan: true, status: "closed")

    refute task.valid?
    assert_includes task.errors, "Plans cannot change status"
  end

  def test_invalid_plan_cannot_have_source_plan_id
    task = TrakFlow::Models::Task.new(title: "T", plan: true, source_plan_id: "tf-other")

    refute task.valid?
    assert_includes task.errors, "Plans cannot be derived from other Plans"
  end

  def test_valid_plan
    plan = TrakFlow::Models::Task.new(title: "Valid Plan", plan: true, status: "open")

    assert plan.valid?
  end

  # Trace logging

  def test_append_trace
    task = TrakFlow::Models::Task.new(title: "T")
    task.append_trace("ACTION", "Something happened")

    assert_match(/\[ACTION\] Something happened/, task.notes)
    assert_match(/\d{4}-\d{2}-\d{2}T/, task.notes)
  end

  # Serialization with new fields

  def test_to_h_includes_plan_workflow_fields
    task = TrakFlow::Models::Task.new(
      id: "tf-test",
      title: "Test",
      plan: true,
      source_plan_id: nil,
      ephemeral: false,
      notes: "Some notes"
    )

    hash = task.to_h

    assert_equal true, hash[:plan]
    assert_equal false, hash[:ephemeral]
    assert_equal "Some notes", hash[:notes]
  end

  def test_from_hash_deserializes_plan_workflow_fields
    hash = {
      id: "tf-wf-1",
      title: "Workflow",
      plan: false,
      source_plan_id: "tf-plan-1",
      ephemeral: true,
      notes: "Created from plan"
    }

    task = TrakFlow::Models::Task.from_hash(hash)

    refute task.plan?
    assert task.workflow?
    assert task.ephemeral?
    assert_equal "tf-plan-1", task.source_plan_id
    assert_equal "Created from plan", task.notes
  end

end
