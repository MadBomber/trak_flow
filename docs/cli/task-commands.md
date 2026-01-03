# Task Commands

Commands for creating and managing tasks.

## Create Task

Create a new task.

```bash
tf create TITLE [OPTIONS]
```

### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--description` | `-d` | Detailed description |
| `--type` | `-t` | Task type (task, bug, feature, epic, chore) |
| `--priority` | `-p` | Priority level (0-4) |
| `--assignee` | `-a` | Assign to user/agent |
| `--parent` | | Parent task ID for hierarchy |
| `--plan` | | Create as a Plan blueprint |

### Examples

```bash
# Basic task
tf create "Fix login bug"

# With type and priority
tf create "Security vulnerability" -t bug -p 0

# With description
tf create "Add OAuth" -d "Implement OAuth 2.0 with Google and GitHub providers"

# Child task
tf create "Design login page" --parent tf-abc123

# Create a Plan
tf create "Release Checklist" --plan
```

## List Tasks

List tasks with filtering options.

```bash
tf list [OPTIONS]
```

### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--status` | `-s` | Filter by status |
| `--type` | `-t` | Filter by type |
| `--priority` | `-p` | Filter by priority |
| `--assignee` | `-a` | Filter by assignee |
| `--label` | `-l` | Filter by label (repeatable) |
| `--parent` | | Show only children of task |
| `--no-children` | | Exclude child tasks |
| `--json` | | Output as JSON |

### Examples

```bash
# All open tasks
tf list

# By status
tf list --status in_progress
tf list -s blocked

# By type
tf list --type bug
tf list -t feature

# By priority
tf list --priority 0
tf list -p high

# By label
tf list --label frontend
tf list -l urgent -l frontend

# Combine filters
tf list -s open -t bug -p 0

# JSON output
tf list --json
```

### Status Values

- `open` - Ready to work on
- `in_progress` - Currently being worked on
- `blocked` - Waiting on something
- `deferred` - Postponed
- `closed` - Completed
- `all` - Include all statuses

## Show Task

Display detailed information about a task.

```bash
tf show TASK_ID [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--tree` | Show child tasks in tree format |
| `--deps` | Show dependencies |
| `--json` | Output as JSON |

### Examples

```bash
tf show tf-abc123

tf show tf-abc123 --tree

tf show tf-abc123 --deps
```

### Output

```
Task: tf-abc123
Title: Implement user authentication
Type: feature
Status: in_progress
Priority: 1 (high)
Assignee: claude
Created: 2024-01-15 10:00:00
Updated: 2024-01-16 14:30:00

Description:
  Add authentication system with login, logout, and session management.

Labels:
  - backend
  - security

Dependencies:
  Blocked by:
    - tf-design1 (closed)
  Blocks:
    - tf-test1 (open)
    - tf-docs1 (open)

Notes:
  [2024-01-16T14:30:00Z] [STARTED] Beginning implementation
  [2024-01-15T10:00:00Z] [CREATED] Initial task creation
```

## Update Task

Modify task properties.

```bash
tf update TASK_ID [OPTIONS]
```

### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--title` | | New title |
| `--description` | `-d` | New description |
| `--type` | `-t` | New type |
| `--priority` | `-p` | New priority |
| `--assignee` | `-a` | New assignee |
| `--notes` | `-n` | Append to notes |

### Examples

```bash
# Change title
tf update tf-abc123 --title "New title"

# Change priority
tf update tf-abc123 -p 0

# Add notes
tf update tf-abc123 --notes "Waiting for design review"

# Change assignee
tf update tf-abc123 -a alice
```

## Status Commands

### Start Task

Mark a task as in progress.

```bash
tf start TASK_ID
```

### Block Task

Mark a task as blocked.

```bash
tf block TASK_ID [--reason "reason"]
```

### Defer Task

Postpone a task.

```bash
tf defer TASK_ID [--until DATE]
```

### Close Task

Complete a task.

```bash
tf close TASK_ID [--summary "completion summary"]
```

### Reopen Task

Reopen a closed or deferred task.

```bash
tf reopen TASK_ID
```

### Examples

```bash
# Start working
tf start tf-abc123

# Hit a blocker
tf block tf-abc123 --reason "Waiting for API access"

# Postpone
tf defer tf-abc123 --until "next week"

# Complete
tf close tf-abc123 --summary "Implemented in PR #42"

# Reopen
tf reopen tf-abc123
```

## Find Ready Tasks

Find tasks that are ready to work on (no open blockers).

```bash
tf ready [OPTIONS]
```

### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--type` | `-t` | Filter by type |
| `--priority` | `-p` | Filter by priority |
| `--assignee` | `-a` | Filter by assignee |
| `--label` | `-l` | Filter by label |
| `--limit` | `-n` | Max results |

### Examples

```bash
# All ready tasks
tf ready

# Ready bugs
tf ready -t bug

# Ready high-priority tasks
tf ready -p 0,1

# Top 5 ready tasks
tf ready -n 5
```

## Delete Task

Remove a task permanently.

```bash
tf delete TASK_ID [--force]
```

!!! warning
    This is destructive. Use `--force` to skip confirmation.

### Examples

```bash
# With confirmation
tf delete tf-abc123

# Without confirmation
tf delete tf-abc123 --force
```

## Bulk Operations

### Using Shell Loops

```bash
# Close all tasks with a label
tf list --label sprint-42 --json | \
  jq -r '.[].id' | \
  xargs -I {} tf close {}

# Add label to multiple tasks
for id in tf-abc123 tf-def456 tf-ghi789; do
  tf label add $id "urgent"
done
```

### Using xargs

```bash
# Defer all low-priority tasks
tf list -p 4 --json | \
  jq -r '.[].id' | \
  xargs -I {} tf defer {}
```
