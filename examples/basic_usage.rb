#!/usr/bin/env ruby
# frozen_string_literal: true

# TrakFlow Basic Usage Demo
#
# This example demonstrates the core functionality of TrakFlow,
# a distributed task tracking system designed for robots/AI agents.
#
# Run with: bundle exec ruby examples/basic_usage.rb

require "bundler/setup"
require "trak_flow"
require "fileutils"
require "tmpdir"

# Create a temporary directory for the demo
demo_dir = Dir.mktmpdir("trak_flow_demo")
Dir.chdir(demo_dir)

# Reset TrakFlow to use the demo directory
TrakFlow.reset_root!
TrakFlow.reset_config!

puts <<~HEADER
  ============================================================
  TrakFlow Basic Usage Demo
  ============================================================
  Demo directory: #{demo_dir}

HEADER

# =============================================================================
# 1. Initialize TrakFlow
# =============================================================================

puts "1. Initializing TrakFlow..."
trak_flow_dir = File.join(demo_dir, ".trak_flow")
FileUtils.mkdir_p(trak_flow_dir)

db_path = File.join(trak_flow_dir, "trak_flow.db")
db = TrakFlow::Storage::Database.new(db_path)
db.connect
puts "   Database initialized at #{db_path}\n\n"

# =============================================================================
# 2. Configuration
# =============================================================================

puts "2. Configuration..."
puts "   Actor: #{TrakFlow.config.actor}"
puts "   Output JSON: #{TrakFlow.config.output.json}"
puts "   Daemon auto-start: #{TrakFlow.config.daemon.auto_start}"

# Modify configuration
TrakFlow.configure do |config|
  config.actor = "demo-robot"
end
puts "   Actor (after configure): #{TrakFlow.config.actor}\n\n"

# =============================================================================
# 3. Creating Tasks
# =============================================================================

puts "3. Creating Tasks..."

# Create an epic
epic = TrakFlow::Models::Task.new(
  title: "Build User Authentication System",
  description: "Implement complete user auth with login, logout, and sessions",
  type: "epic",
  priority: 1
)
epic = db.create_task(epic)
puts "   Created epic: [#{epic.id}] #{epic.title}"

# Create regular tasks
task1 = TrakFlow::Models::Task.new(
  title: "Design database schema for users",
  description: "Create tables for users, sessions, and password resets",
  type: "task",
  priority: 1,
  assignee: "demo-robot"
)
task1 = db.create_task(task1)
puts "   Created task: [#{task1.id}] #{task1.title}"

task2 = TrakFlow::Models::Task.new(
  title: "Implement login endpoint",
  description: "POST /api/login with email and password",
  type: "feature",
  priority: 2
)
task2 = db.create_task(task2)
puts "   Created feature: [#{task2.id}] #{task2.title}"

task3 = TrakFlow::Models::Task.new(
  title: "Write login integration tests",
  type: "task",
  priority: 3
)
task3 = db.create_task(task3)
puts "   Created task: [#{task3.id}] #{task3.title}"

# Create a bug
bug = TrakFlow::Models::Task.new(
  title: "Fix password validation regex",
  description: "Current regex doesn't allow special characters",
  type: "bug",
  priority: 0  # Highest priority
)
bug = db.create_task(bug)
puts "   Created bug: [#{bug.id}] #{bug.title}\n\n"

# =============================================================================
# 4. Dependencies
# =============================================================================

puts "4. Setting up Dependencies..."

# Task2 (login endpoint) is blocked by Task1 (database schema)
dep1 = TrakFlow::Models::Dependency.new(
  source_id: task1.id,
  target_id: task2.id,
  type: "blocks"
)
db.add_dependency(dep1)
puts "   #{task1.id} blocks #{task2.id}"

# Task3 (tests) is blocked by Task2 (login endpoint)
dep2 = TrakFlow::Models::Dependency.new(
  source_id: task2.id,
  target_id: task3.id,
  type: "blocks"
)
db.add_dependency(dep2)
puts "   #{task2.id} blocks #{task3.id}"

# Epic is related to all tasks
dep3 = TrakFlow::Models::Dependency.new(
  source_id: epic.id,
  target_id: task1.id,
  type: "related"
)
db.add_dependency(dep3)
puts "   #{epic.id} related to #{task1.id}\n\n"

# =============================================================================
# 5. Labels
# =============================================================================

puts "5. Adding Labels..."

# Add labels to the bug
label1 = TrakFlow::Models::Label.new(task_id: bug.id, name: "critical")
db.add_label(label1)
puts "   Added 'critical' label to #{bug.id}"

label2 = TrakFlow::Models::Label.new(task_id: bug.id, name: "security")
db.add_label(label2)
puts "   Added 'security' label to #{bug.id}"

# Use state labels (dimension:value format)
db.set_state(task1.id, "complexity", "medium", reason: "Standard CRUD operations")
puts "   Set complexity:medium on #{task1.id}"

state = db.get_state(task1.id, "complexity")
puts "   Retrieved state - complexity: #{state}\n\n"

# =============================================================================
# 6. Comments
# =============================================================================

puts "6. Adding Comments..."

comment1 = TrakFlow::Models::Comment.new(
  task_id: task1.id,
  author: "demo-robot",
  body: "Starting work on the users table schema."
)
db.add_comment(comment1)
puts "   Added comment to #{task1.id}"

comment2 = TrakFlow::Models::Comment.new(
  task_id: task1.id,
  author: "demo-robot",
  body: "Schema draft complete. Ready for review."
)
db.add_comment(comment2)
puts "   Added comment to #{task1.id}"

comments = db.find_comments(task1.id)
puts "   Task #{task1.id} has #{comments.size} comments\n\n"

# =============================================================================
# 7. Querying Tasks
# =============================================================================

puts "7. Querying Tasks..."

# List all tasks
all_tasks = db.list_tasks
puts "   Total tasks: #{all_tasks.size}"

# Filter by status
open_tasks = db.list_tasks(status: "open")
puts "   Open tasks: #{open_tasks.size}"

# Filter by priority
high_priority = db.list_tasks(priority: 0)
puts "   P0 (highest priority) tasks: #{high_priority.size}"

# Filter by type
bugs = db.list_tasks(type: "bug")
puts "   Bugs: #{bugs.size}"

# Filter by assignee
my_tasks = db.list_tasks(assignee: "demo-robot")
puts "   Tasks assigned to demo-robot: #{my_tasks.size}\n\n"

# =============================================================================
# 8. Ready Work Detection
# =============================================================================

puts "8. Ready Work Detection..."

ready = db.ready_tasks
puts "   Tasks ready to work on (not blocked):"
ready.each do |task|
  puts "     [#{task.id}] P#{task.priority} #{task.type}: #{task.title}"
end

blocked = db.blocked_tasks
puts "\n   Blocked tasks:"
blocked.each do |task|
  deps = db.blocking_dependencies(task.id)
  blocker_ids = deps.map(&:source_id).join(", ")
  puts "     [#{task.id}] #{task.title} (blocked by: #{blocker_ids})"
end
puts

# =============================================================================
# 9. Task Lifecycle
# =============================================================================

puts "9. Task Lifecycle..."

# Start working on the bug (highest priority, not blocked)
bug_fresh = db.find_task!(bug.id)
bug_fresh.status = "in_progress"
db.update_task(bug_fresh)
puts "   Bug #{bug.id} status: #{bug_fresh.status}"

# Complete the bug
bug_fresh.close!(reason: "Fixed regex to allow !@#$%^&*()")
db.update_task(bug_fresh)
puts "   Bug #{bug.id} closed at: #{bug_fresh.closed_at}"

# Complete task1 to unblock task2
task1_fresh = db.find_task!(task1.id)
task1_fresh.close!(reason: "Schema implemented and migrated")
db.update_task(task1_fresh)
puts "   Task #{task1.id} closed"

# Check ready work again
ready = db.ready_tasks
puts "\n   Tasks ready after completing task1:"
ready.each do |task|
  puts "     [#{task.id}] P#{task.priority} #{task.type}: #{task.title}"
end
puts

# =============================================================================
# 10. Child Tasks (for Epics)
# =============================================================================

puts "10. Creating Child Tasks..."

child1 = db.create_child_task(epic.id, {
  title: "Setup OAuth providers",
  type: "task",
  priority: 2
})
puts "   Created child: [#{child1.id}] #{child1.title}"

child2 = db.create_child_task(epic.id, {
  title: "Add 2FA support",
  type: "feature",
  priority: 3
})
puts "   Created child: [#{child2.id}] #{child2.title}"

children = db.child_tasks(epic.id)
puts "   Epic #{epic.id} has #{children.size} children\n\n"

# =============================================================================
# 11. Plans and Workflows
# =============================================================================

puts "11. Plans and Workflows..."

# Create a Plan (workflow blueprint)
plan = TrakFlow::Models::Task.new(
  title: "Deploy to Production",
  plan: true
)
plan = db.create_task(plan)
puts "   Created plan: [#{plan.id}] #{plan.title}"

# Add steps to the plan
step1 = db.create_child_task(plan.id, { title: "Run tests" })
step2 = db.create_child_task(plan.id, { title: "Build artifacts" })
step3 = db.create_child_task(plan.id, { title: "Deploy to staging" })
puts "   Added #{db.find_plan_tasks(plan.id).size} steps to plan"

# List all plans
plans = db.find_plans
puts "   Total plans: #{plans.size}"

# Create an ephemeral task (temporary, garbage collectible)
ephemeral = TrakFlow::Models::Task.new(
  title: "Quick note: Check session timeout setting",
  ephemeral: true
)
ephemeral = db.create_task(ephemeral)
puts "   Created ephemeral task: [#{ephemeral.id}] #{ephemeral.title}"

ephemeral_tasks = db.find_ephemeral_workflows
puts "   Total ephemeral tasks: #{ephemeral_tasks.size}"

# Garbage collection would remove old ephemeral tasks
# gc_count = db.garbage_collect_ephemeral(max_age_hours: 24)
puts

# =============================================================================
# Summary
# =============================================================================

puts <<~SUMMARY
  ============================================================
  Demo Complete!
  ============================================================

  What we demonstrated:
  - Initialized TrakFlow database
  - Configured settings via TrakFlow.configure
  - Created tasks of various types (epic, task, feature, bug)
  - Set up blocking and related dependencies
  - Added labels and state labels (dimension:value)
  - Added comments to tasks
  - Queried tasks with filters
  - Detected ready work vs blocked tasks
  - Managed task lifecycle (open -> in_progress -> closed)
  - Created child tasks under an epic
  - Created Plans (workflow blueprints) with steps
  - Created ephemeral tasks (temporary, garbage collectible)

  Database location: #{db_path}
  Dirty (needs flush): #{db.dirty?}

SUMMARY

# Cleanup
db.close
FileUtils.rm_rf(demo_dir)
puts "Demo directory cleaned up."
