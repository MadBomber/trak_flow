# Database API Reference

TrakFlow uses SQLite for fast querying with JSONL as the persistent source of truth.

## Class: TrakFlow::Storage::Database

### Initialization

```ruby
db = TrakFlow::Storage::Database.new(path)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | String | Path to SQLite database file |

### Task Methods

#### find_task

Find a task by ID.

```ruby
task = db.find_task("tf-abc123")
# Returns: TrakFlow::Models::Task or nil
```

#### list_tasks

List tasks with optional filters.

```ruby
tasks = db.list_tasks(
  status: "open",
  type: "bug",
  priority: [0, 1],
  assignee: "claude",
  parent_id: nil,
  label: "frontend",
  include_closed: false,
  include_ephemeral: false,
  limit: 100,
  offset: 0
)
# Returns: Array<TrakFlow::Models::Task>
```

| Filter | Type | Description |
|--------|------|-------------|
| `status` | String/Array | Filter by status(es) |
| `type` | String/Array | Filter by type(s) |
| `priority` | Integer/Array | Filter by priority(ies) |
| `assignee` | String | Filter by assignee |
| `parent_id` | String | Filter by parent |
| `label` | String/Array | Filter by label(s) |
| `include_closed` | Boolean | Include closed tasks |
| `include_ephemeral` | Boolean | Include ephemeral tasks |
| `limit` | Integer | Max results |
| `offset` | Integer | Skip results |

#### insert_task

Insert a new task.

```ruby
db.insert_task(task)
# Returns: TrakFlow::Models::Task
```

#### update_task

Update an existing task.

```ruby
db.update_task(task)
# Returns: TrakFlow::Models::Task
```

#### delete_task

Delete a task.

```ruby
db.delete_task("tf-abc123")
# Returns: true
```

### Ready Tasks

#### find_ready_tasks

Find tasks with no open blocking dependencies.

```ruby
tasks = db.find_ready_tasks(
  type: "bug",
  priority: [0, 1],
  limit: 10
)
# Returns: Array<TrakFlow::Models::Task>
```

#### is_ready?

Check if a task is ready.

```ruby
db.is_ready?("tf-abc123")
# Returns: Boolean
```

### Plan & Workflow Methods

#### find_plans

Find all Plan blueprints.

```ruby
plans = db.find_plans
# Returns: Array<TrakFlow::Models::Task> where plan? == true
```

#### find_workflows

Find Workflows, optionally filtered by source Plan.

```ruby
workflows = db.find_workflows(plan_id: "tf-plan1")
# Returns: Array<TrakFlow::Models::Task> where workflow? == true
```

#### find_ephemeral_workflows

Find ephemeral Workflows.

```ruby
workflows = db.find_ephemeral_workflows
# Returns: Array<TrakFlow::Models::Task> where ephemeral? == true
```

#### mark_as_plan

Convert a task to a Plan.

```ruby
db.mark_as_plan("tf-abc123")
# Returns: TrakFlow::Models::Task
```

### Dependency Methods

#### add_dependency

Add a dependency between tasks.

```ruby
db.add_dependency(
  source_id: "tf-design",
  target_id: "tf-implement",
  type: "blocks"
)
# Returns: TrakFlow::Models::Dependency
```

#### remove_dependency

Remove a dependency.

```ruby
db.remove_dependency(
  source_id: "tf-design",
  target_id: "tf-implement"
)
# Returns: true
```

#### dependencies_for

Get dependencies for a task.

```ruby
deps = db.dependencies_for("tf-abc123")
# Returns: {
#   blocked_by: Array<Dependency>,
#   blocks: Array<Dependency>,
#   related: Array<Dependency>
# }
```

#### all_dependencies

Get all dependencies.

```ruby
deps = db.all_dependencies
# Returns: Array<TrakFlow::Models::Dependency>
```

#### would_create_cycle?

Check if adding a dependency would create a cycle.

```ruby
db.would_create_cycle?("tf-a", "tf-b")
# Returns: Boolean
```

### Label Methods

#### add_label

Add a label to a task.

```ruby
db.add_label("tf-abc123", "frontend")
# Returns: TrakFlow::Models::Label
```

#### remove_label

Remove a label from a task.

```ruby
db.remove_label("tf-abc123", "frontend")
# Returns: true
```

#### labels_for

Get labels for a task.

```ruby
labels = db.labels_for("tf-abc123")
# Returns: Array<String>
```

#### all_labels

Get all labels with task counts.

```ruby
labels = db.all_labels
# Returns: Hash<String, Integer>
# Example: {"frontend" => 5, "backend" => 3}
```

#### tasks_with_label

Find tasks with a label.

```ruby
tasks = db.tasks_with_label("frontend")
# Returns: Array<TrakFlow::Models::Task>
```

### Comment Methods

#### add_comment

Add a comment to a task.

```ruby
db.add_comment(
  task_id: "tf-abc123",
  author: "claude",
  content: "Working on this now"
)
# Returns: TrakFlow::Models::Comment
```

#### comments_for

Get comments for a task.

```ruby
comments = db.comments_for("tf-abc123")
# Returns: Array<TrakFlow::Models::Comment>
```

### Maintenance Methods

#### rebuild!

Rebuild the database from JSONL.

```ruby
db.rebuild!(jsonl_path)
# Returns: Integer (number of tasks loaded)
```

#### garbage_collect!

Remove old ephemeral Workflows.

```ruby
count = db.garbage_collect!(older_than: 7.days.ago)
# Returns: Integer (number deleted)
```

#### vacuum!

Optimize database storage.

```ruby
db.vacuum!
```

### Statistics Methods

#### stats

Get database statistics.

```ruby
stats = db.stats
# Returns: {
#   total_tasks: 47,
#   by_status: {"open" => 12, "closed" => 27, ...},
#   by_type: {"task" => 30, "bug" => 8, ...},
#   by_priority: {0 => 2, 1 => 8, ...},
#   plans: 3,
#   workflows: 5,
#   dependencies: 34,
#   labels: 12
# }
```

## Schema

### tasks Table

```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'open',
  priority INTEGER DEFAULT 2,
  type TEXT DEFAULT 'task',
  assignee TEXT,
  parent_id TEXT,
  created_at TEXT,
  updated_at TEXT,
  closed_at TEXT,
  content_hash TEXT,
  plan BOOLEAN DEFAULT 0,
  source_plan_id TEXT,
  ephemeral BOOLEAN DEFAULT 0,
  notes TEXT
);

CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_priority ON tasks(priority);
CREATE INDEX idx_tasks_type ON tasks(type);
CREATE INDEX idx_tasks_parent_id ON tasks(parent_id);
CREATE INDEX idx_tasks_plan ON tasks(plan);
CREATE INDEX idx_tasks_source_plan_id ON tasks(source_plan_id);
```

### dependencies Table

```sql
CREATE TABLE dependencies (
  id TEXT PRIMARY KEY,
  source_id TEXT NOT NULL,
  target_id TEXT NOT NULL,
  type TEXT DEFAULT 'blocks',
  created_at TEXT,
  FOREIGN KEY (source_id) REFERENCES tasks(id),
  FOREIGN KEY (target_id) REFERENCES tasks(id),
  UNIQUE(source_id, target_id)
);

CREATE INDEX idx_deps_source ON dependencies(source_id);
CREATE INDEX idx_deps_target ON dependencies(target_id);
```

### labels Table

```sql
CREATE TABLE labels (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at TEXT,
  FOREIGN KEY (task_id) REFERENCES tasks(id),
  UNIQUE(task_id, name)
);

CREATE INDEX idx_labels_task_id ON labels(task_id);
CREATE INDEX idx_labels_name ON labels(name);
```

### comments Table

```sql
CREATE TABLE comments (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL,
  author TEXT,
  content TEXT NOT NULL,
  created_at TEXT,
  FOREIGN KEY (task_id) REFERENCES tasks(id)
);

CREATE INDEX idx_comments_task_id ON comments(task_id);
```

## Transaction Support

```ruby
db.transaction do
  task1 = db.insert_task(task1)
  task2 = db.insert_task(task2)
  db.add_dependency(task1.id, task2.id)
end
# All operations succeed or all fail
```

## Error Handling

```ruby
begin
  db.find_task("invalid-id")
rescue TrakFlow::Storage::NotFoundError => e
  puts "Not found: #{e.message}"
end

begin
  db.add_dependency("tf-a", "tf-a")
rescue TrakFlow::Storage::ValidationError => e
  puts "Invalid: #{e.message}"
end
```
