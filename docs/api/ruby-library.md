# Ruby Library Reference

TrakFlow can be used as a Ruby library for programmatic task management.

## Installation

```ruby
# Gemfile
gem 'trak_flow'
```

## Quick Start

```ruby
require 'trak_flow'

# Initialize with default configuration
trak = TrakFlow.new

# Create a task
task = trak.create_task(
  title: "Implement feature X",
  type: "feature",
  priority: 1
)
puts "Created: #{task.id}"

# List open tasks
tasks = trak.list_tasks(status: "open")
tasks.each { |t| puts "#{t.id}: #{t.title}" }

# Update a task
trak.start_task(task.id)
trak.close_task(task.id, summary: "Implemented in PR #42")
```

## Configuration

### Default Configuration

```ruby
trak = TrakFlow.new
# Uses .trak_flow/ in current directory
```

### Custom Configuration

```ruby
trak = TrakFlow.new(
  data_dir: "/path/to/data",
  config: {
    default_priority: 2,
    gc_retention: "7d"
  }
)
```

### Configuration from File

```ruby
trak = TrakFlow.from_config("/path/to/config.json")
```

## Core Classes

### TrakFlow

Main entry point for all operations.

```ruby
trak = TrakFlow.new(options = {})
```

#### Task Methods

| Method | Description |
|--------|-------------|
| `create_task(attrs)` | Create a new task |
| `find_task(id)` | Find task by ID |
| `list_tasks(filters)` | List tasks with filters |
| `update_task(id, attrs)` | Update task attributes |
| `start_task(id)` | Mark as in_progress |
| `close_task(id, summary:)` | Mark as closed |
| `block_task(id, reason:)` | Mark as blocked |
| `reopen_task(id)` | Reopen closed task |
| `delete_task(id)` | Delete task |

#### Plan Methods

| Method | Description |
|--------|-------------|
| `create_plan(title, description:)` | Create a Plan |
| `add_step(plan_id, title, attrs)` | Add step to Plan |
| `start_plan(plan_id, title:)` | Create persistent Workflow |
| `execute_plan(plan_id, title:)` | Create ephemeral Workflow |
| `list_plans` | List all Plans |
| `list_workflows(plan_id:)` | List Workflows |

#### Dependency Methods

| Method | Description |
|--------|-------------|
| `add_dependency(source, target, type:)` | Add dependency |
| `remove_dependency(source, target)` | Remove dependency |
| `ready_tasks(filters)` | Find tasks with no blockers |
| `dependency_tree(task_id)` | Get dependency tree |

#### Label Methods

| Method | Description |
|--------|-------------|
| `add_label(task_id, label)` | Add label to task |
| `remove_label(task_id, label)` | Remove label |
| `labels_for(task_id)` | Get task's labels |
| `all_labels` | List all labels |

### TrakFlow::Models::Task

Represents a task.

```ruby
task = trak.find_task("tf-abc123")

# Properties
task.id           # => "tf-abc123"
task.title        # => "Implement feature"
task.description  # => "Detailed description"
task.status       # => "in_progress"
task.priority     # => 1
task.type         # => "feature"
task.assignee     # => "claude"
task.parent_id    # => nil
task.created_at   # => Time
task.updated_at   # => Time
task.closed_at    # => nil
task.notes        # => "..."
task.content_hash # => "a1b2c3d4"

# Plan/Workflow properties
task.plan           # => false
task.source_plan_id # => nil
task.ephemeral      # => false

# Predicates
task.open?        # => false
task.closed?      # => false
task.in_progress? # => true
task.blocked?     # => false
task.plan?        # => false
task.workflow?    # => false
task.ephemeral?   # => false
task.executable?  # => true
task.discardable? # => false
```

### TrakFlow::Storage::Database

SQLite storage layer.

```ruby
db = TrakFlow::Storage::Database.new("/path/to/trak_flow.db")

# Query methods
db.find_task(id)
db.list_tasks(filters)
db.find_ready_tasks
db.find_plans
db.find_workflows(plan_id:)

# Write methods
db.insert_task(task)
db.update_task(task)
db.delete_task(id)

# Dependency methods
db.add_dependency(source, target, type)
db.remove_dependency(source, target)
db.dependencies_for(task_id)
```

### TrakFlow::Storage::Jsonl

JSONL file storage.

```ruby
jsonl = TrakFlow::Storage::Jsonl.new("/path/to/issues.jsonl")

# Load all tasks
tasks = jsonl.load_all

# Append a task
jsonl.append(task)

# Rewrite entire file
jsonl.save_all(tasks)
```

## Examples

### Create and Manage Tasks

```ruby
require 'trak_flow'

trak = TrakFlow.new

# Create a feature with subtasks
feature = trak.create_task(
  title: "User Authentication",
  type: "epic",
  priority: 1
)

login = trak.create_task(
  title: "Login page",
  parent_id: feature.id
)

logout = trak.create_task(
  title: "Logout functionality",
  parent_id: feature.id
)

# Add dependencies
trak.add_dependency(login.id, logout.id)

# Find ready work
ready = trak.ready_tasks
puts "Ready to work on: #{ready.map(&:title)}"

# Complete the workflow
trak.start_task(login.id)
trak.close_task(login.id, summary: "Implemented login")

# Now logout is ready
ready = trak.ready_tasks
puts "Now ready: #{ready.map(&:title)}"
```

### Work with Plans

```ruby
require 'trak_flow'

trak = TrakFlow.new

# Create a release plan
plan = trak.create_plan("Release Process")
trak.add_step(plan.id, "Update version number")
trak.add_step(plan.id, "Update CHANGELOG")
trak.add_step(plan.id, "Run tests")
trak.add_step(plan.id, "Create release tag")
trak.add_step(plan.id, "Publish gem")

# Start a release workflow
workflow = trak.start_plan(plan.id, title: "Release v1.0.0")

# Work through the steps
workflow.tasks.each do |task|
  puts "Starting: #{task.title}"
  trak.start_task(task.id)
  # ... do the work ...
  trak.close_task(task.id)
  puts "Completed: #{task.title}"
end

# Summarize the workflow
trak.summarize_workflow(workflow.id, summary: "Released v1.0.0")
```

### Filtering and Querying

```ruby
require 'trak_flow'

trak = TrakFlow.new

# Filter by multiple criteria
bugs = trak.list_tasks(
  status: "open",
  type: "bug",
  priority: [0, 1]  # Critical or High
)

# Filter by label
frontend = trak.list_tasks(label: "frontend")

# Complex queries using the database directly
db = trak.database
high_priority_ready = db.list_tasks.select do |task|
  task.priority <= 1 && db.is_ready?(task.id)
end
```

### Dependency Analysis

```ruby
require 'trak_flow'

trak = TrakFlow.new

# Get dependency tree
tree = trak.dependency_tree("tf-abc123")

puts "Blocked by:"
tree[:blocked_by].each { |t| puts "  - #{t.title}" }

puts "Blocks:"
tree[:blocks].each { |t| puts "  - #{t.title}" }

# Check for cycles
if trak.would_create_cycle?("tf-a", "tf-b")
  puts "Warning: would create a cycle!"
end
```

## Error Handling

```ruby
require 'trak_flow'

trak = TrakFlow.new

begin
  task = trak.find_task("invalid-id")
rescue TrakFlow::NotFoundError => e
  puts "Task not found: #{e.message}"
end

begin
  trak.create_task(title: "")  # Empty title
rescue TrakFlow::ValidationError => e
  puts "Validation failed: #{e.message}"
end

begin
  trak.add_dependency("tf-a", "tf-a")  # Self-reference
rescue TrakFlow::DependencyError => e
  puts "Invalid dependency: #{e.message}"
end
```

## Thread Safety

The library is designed for single-threaded use. For concurrent access:

1. Use separate `TrakFlow` instances per thread
2. Or use the MCP server for concurrent access
3. The SQLite database handles concurrent reads safely
