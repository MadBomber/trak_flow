# Task Model Reference

The Task model is the core data structure in TrakFlow.

## Class: TrakFlow::Models::Task

### Initialization

```ruby
task = TrakFlow::Models::Task.new(
  title: "Task title",
  description: "Optional description",
  type: "task",
  priority: 2,
  assignee: nil,
  parent_id: nil,
  plan: false,
  ephemeral: false
)
```

### Attributes

#### Required Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `title` | String | Task title (required) |

#### Auto-Generated Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | String | Unique ID (e.g., `tf-abc123`) |
| `created_at` | Time | Creation timestamp |
| `updated_at` | Time | Last update timestamp |
| `content_hash` | String | Hash of task content |

#### Optional Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `description` | String | `nil` | Detailed description |
| `status` | String | `"open"` | Current status |
| `priority` | Integer | `2` | Priority level (0-4) |
| `type` | String | `"task"` | Task type |
| `assignee` | String | `nil` | Assigned user/agent |
| `parent_id` | String | `nil` | Parent task ID |
| `closed_at` | Time | `nil` | When task was closed |
| `notes` | String | `""` | Free-form notes |

#### Plan/Workflow Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `plan` | Boolean | `false` | Is this a Plan blueprint |
| `source_plan_id` | String | `nil` | Source Plan for Workflows |
| `ephemeral` | Boolean | `false` | Is this ephemeral |

### Status Values

| Status | Description |
|--------|-------------|
| `open` | Ready to work on |
| `in_progress` | Currently being worked on |
| `blocked` | Waiting on something |
| `deferred` | Postponed for later |
| `closed` | Completed |
| `tombstone` | Archived (permanent) |
| `pinned` | Highlighted for visibility |

### Type Values

| Type | Description |
|------|-------------|
| `task` | General task (default) |
| `bug` | Bug fix |
| `feature` | New feature |
| `epic` | Large initiative |
| `chore` | Maintenance work |

### Priority Levels

| Level | Name | Description |
|-------|------|-------------|
| 0 | Critical | Urgent, drop everything |
| 1 | High | Important, do soon |
| 2 | Medium | Normal priority (default) |
| 3 | Low | Do when time permits |
| 4 | Backlog | Future consideration |

## Predicate Methods

```ruby
task = TrakFlow::Models::Task.new(title: "Example")

# Status predicates
task.open?        # status == "open"
task.closed?      # status == "closed" or "tombstone"
task.in_progress? # status == "in_progress"
task.blocked?     # status == "blocked"
task.deferred?    # status == "deferred"

# Type predicates
task.bug?         # type == "bug"
task.feature?     # type == "feature"
task.epic?        # type == "epic"
task.chore?       # type == "chore"

# Plan/Workflow predicates
task.plan?        # plan == true
task.workflow?    # source_plan_id present and not a plan
task.ephemeral?   # ephemeral == true

# Capability predicates
task.executable?  # not a plan (can be executed)
task.discardable? # ephemeral (can be discarded)
```

## Instance Methods

### Status Transitions

```ruby
task.start!       # -> in_progress
task.block!       # -> blocked
task.defer!       # -> deferred
task.close!       # -> closed
task.reopen!      # -> open
task.archive!     # -> tombstone
```

### Content Management

```ruby
# Update timestamp
task.touch!

# Append to notes with trace entry
task.append_trace("STARTED", "Beginning implementation")
# Adds: [2024-01-15T10:00:00Z] [STARTED] Beginning implementation

# Compute content hash
task.compute_hash!
```

### Serialization

```ruby
# Convert to Hash
hash = task.to_h

# Convert to JSON
json = task.to_json

# Create from Hash
task = TrakFlow::Models::Task.from_hash(hash)

# Create from JSON
task = TrakFlow::Models::Task.from_json(json)
```

## Validation

Tasks are validated on creation and update:

```ruby
task = TrakFlow::Models::Task.new(title: "")
task.valid?  # => false
task.errors  # => ["Title is required"]

task = TrakFlow::Models::Task.new(
  title: "Test",
  status: "invalid"
)
task.valid?  # => false
task.errors  # => ["Invalid status: invalid"]
```

### Validation Rules

| Rule | Error Message |
|------|---------------|
| Title required | "Title is required" |
| Valid status | "Invalid status: {status}" |
| Valid priority | "Invalid priority: {priority}" |
| Valid type | "Invalid type: {type}" |
| Plans can't be ephemeral | "Plans cannot be ephemeral" |
| Plans stay open | "Plans cannot change status" |
| Plans can't derive from Plans | "Plans cannot be derived from other Plans" |

## ID Generation

IDs are generated using content hashing:

```ruby
task = TrakFlow::Models::Task.new(title: "Example")
task.generate_id!
task.id  # => "tf-a1b2c3d4"
```

The ID is derived from:
- Title
- Description
- Type
- Creation timestamp
- Random salt (for uniqueness)

### ID Format

```
tf-xxxxxxxx
```

- `tf-` prefix identifies TrakFlow tasks
- 8 character hex hash

## JSON Representation

```json
{
  "id": "tf-abc123",
  "title": "Implement feature X",
  "description": "Detailed description here",
  "status": "in_progress",
  "priority": 1,
  "type": "feature",
  "assignee": "claude",
  "parent_id": null,
  "created_at": "2024-01-15T10:00:00Z",
  "updated_at": "2024-01-15T14:30:00Z",
  "closed_at": null,
  "content_hash": "a1b2c3d4",
  "plan": false,
  "source_plan_id": null,
  "ephemeral": false,
  "notes": ""
}
```

## Content Hash

The content hash enables:

1. **Change detection** - Know when content was modified
2. **Deduplication** - Identify identical tasks
3. **Sync support** - Merge changes from multiple sources

### Hash Computation

```ruby
# Automatically computed on save
task.compute_hash!

# Hash is based on:
# - title
# - description
# - type
# - priority
# - assignee
# - status
# - parent_id
# - plan
# - source_plan_id
# - ephemeral
# - notes

# Excluded from hash:
# - id
# - created_at
# - updated_at
# - closed_at
# - content_hash itself
```

## Examples

### Creating Different Task Types

```ruby
# Bug
bug = TrakFlow::Models::Task.new(
  title: "Fix null pointer exception",
  type: "bug",
  priority: 0
)

# Feature
feature = TrakFlow::Models::Task.new(
  title: "Add OAuth support",
  type: "feature",
  priority: 1,
  description: "Support Google and GitHub OAuth"
)

# Epic with children
epic = TrakFlow::Models::Task.new(
  title: "User Management",
  type: "epic"
)

child = TrakFlow::Models::Task.new(
  title: "Login page",
  parent_id: epic.id
)
```

### Creating a Plan

```ruby
plan = TrakFlow::Models::Task.new(
  title: "Deploy Checklist",
  plan: true
)

plan.plan?       # => true
plan.executable? # => false
```

### Status Workflow

```ruby
task = TrakFlow::Models::Task.new(title: "Example")

task.status      # => "open"

task.start!
task.status      # => "in_progress"

task.block!
task.status      # => "blocked"
task.notes       # Contains trace entry

task.reopen!
task.status      # => "open"

task.start!
task.close!
task.status      # => "closed"
task.closed_at   # => Time.now
```
