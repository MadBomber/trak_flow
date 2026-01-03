# TrakFlow

under active development so watch out for frequent changes.

A distributed task tracking system for Robots (agents), implemented in Ruby.

It uses a task dependency-aware graph to codify plans/workflows, allowing robots to handle complex or lengthy work pipelines without losing track of what they are instructed to do. At its core, TrakFlow is a **DAG-based workflow engine**.

## Features

- **Git-backed persistence**: Issues stored as JSONL files, versioned with your code
- **Hash-based IDs**: Prevents merge conflicts when multiple agents work simultaneously
- **SQLite local cache**: Fast indexed queries with millisecond response times
- **Dependency graph**: Track blocking relationships between tasks
- **Ready-work detection**: Find tasks with no open blockers
- **Hierarchical tasks**: Epics, tasks, and sub-tasks
- **Plans and Workflows**: Reusable workflow blueprints with persistent or ephemeral execution
- **Labels and state**: Flexible categorization and dimension-based state tracking

## Installation

Add to your Gemfile:

```ruby
gem 'trak_flow'
```

Or install directly:

```bash
gem install trak_flow
```

## Quick Start

```bash
# Initialize TrakFlow in your project
tf init

# Create a task
tf create "Implement user authentication" -t feature -p 1

# Create a child task
tf create "Add login form" --parent tf-a1b2

# Add a dependency
tf dep add tf-c3d4 tf-a1b2 -t blocks

# Find ready work
tf ready

# Show dependency tree
tf dep tree tf-a1b2

# Close a task
tf close tf-a1b2 -r "Implemented in PR #123"
```

### Working with Plans and Workflows

Plans are reusable workflow blueprints. Workflows are running instances of Plans.

```bash
# Create a Plan (workflow blueprint)
tf plan create "Deploy to Production"

# Add tasks to the Plan
tf plan add tf-plan1 "Run tests"
tf plan add tf-plan1 "Build artifacts"
tf plan add tf-plan1 "Deploy to staging"
tf plan add tf-plan1 "Deploy to production"

# Start a persistent Workflow from the Plan
tf plan start tf-plan1

# Or execute an ephemeral Workflow (auto-cleaned after completion)
tf plan execute tf-plan1

# List all Workflows
tf workflow list

# Discard an ephemeral Workflow
tf workflow discard tf-wf1

# Summarize and close a Workflow
tf workflow summarize tf-wf1 -s "Deployed v2.1.0 successfully"
```

## CLI Reference

### Core Commands

| Command | Description |
|---------|-------------|
| `tf init` | Initialize TrakFlow in the current directory |
| `tf info` | Show database and configuration info |
| `tf create TITLE` | Create a new task |
| `tf show ID` | Show task details |
| `tf list` | List tasks with filters |
| `tf update ID` | Update a task |
| `tf close ID` | Close a task |
| `tf reopen ID` | Reopen a closed task |
| `tf ready` | Show tasks ready for work |
| `tf stale` | Show stale tasks |
| `tf sync` | Sync database with JSONL file |

The `create` command supports additional flags:

```bash
tf create TITLE [options]
  -t, --type TYPE        # Task type (bug, feature, task, epic, chore)
  -p, --priority NUM     # Priority (0=critical, 4=backlog)
  -d, --description TEXT # Task description
  -a, --assignee NAME    # Assignee
  --parent ID            # Create as child of another task
  --plan                 # Create as a Plan (workflow blueprint)
  --ephemeral            # Create as ephemeral (one-shot)
```

### Issue Types

- `bug` - Bug fixes
- `feature` - New features
- `task` - General tasks
- `epic` - Parent issues containing sub-tasks
- `chore` - Maintenance tasks

### Priority Levels

- `0` - Critical
- `1` - High
- `2` - Medium (default)
- `3` - Low
- `4` - Backlog

### Statuses

- `open` - Ready to work
- `in_progress` - Currently being worked on
- `blocked` - Waiting on dependencies
- `deferred` - Postponed
- `closed` - Complete
- `tombstone` - Archived
- `pinned` - Pinned for visibility

### Dependency Commands

```bash
tf dep add SOURCE TARGET [-t TYPE]  # Add dependency
tf dep remove SOURCE TARGET         # Remove dependency
tf dep tree ID                      # Show dependency tree
```

Dependency types:
- `blocks` - Hard dependency (default)
- `related` - Soft link
- `parent-child` - Hierarchical
- `discovered-from` - Traceability

### Label Commands

```bash
tf label add ID LABEL     # Add label to issue
tf label remove ID LABEL  # Remove label
tf label list ID          # List labels for issue
tf label list-all         # List all labels
```

### Plan Commands

Plans are workflow blueprints that can be instantiated as Workflows.

```bash
tf plan create TITLE      # Create a new Plan
tf plan list              # List all Plans
tf plan list -w           # List all Workflows instead
tf plan show ID           # Show Plan with its tasks
tf plan add PLAN_ID TITLE # Add a task to a Plan
tf plan start PLAN_ID     # Create persistent Workflow from Plan
tf plan execute PLAN_ID   # Create ephemeral Workflow from Plan
tf plan convert ID        # Convert existing task to a Plan
```

### Workflow Commands

Workflows are running instances of Plans.

```bash
tf workflow list          # List all Workflows
tf workflow list -e       # List only ephemeral Workflows
tf workflow show ID       # Show Workflow with its tasks
tf workflow discard ID    # Discard ephemeral Workflow
tf workflow summarize ID  # Summarize and close Workflow
tf workflow gc            # Garbage collect old ephemeral Workflows
```

### Admin Commands

```bash
tf admin cleanup          # Clean up old closed issues
tf admin compact          # Compact the database
tf admin graph            # Generate dependency graph (DOT/SVG)
tf admin analyze          # Analyze the issue graph
```

## Configuration

Configuration is stored in `.trak_flow/config.json`:

```json
{
  "stealth": false,
  "no_push": false,
  "actor": "username",
  "import.orphan_handling": "allow"
}
```

## Architecture

```
.trak_flow/
├── trak_flow.db   # SQLite database (gitignored)
├── issues.jsonl   # Git-tracked source of truth
├── config.json    # Project configuration
└── .gitignore
```

The system uses a three-layer architecture:

1. **CLI Commands** - User-facing Thor commands
2. **SQLite Database** - Fast local queries
3. **JSONL Format** - Git-tracked persistence

## Conceptual Model

TrakFlow uses a single `Task` model that serves multiple roles based on flags:

| Role | Identification | Description |
|------|----------------|-------------|
| **Plan** | `task.plan? == true` | Workflow blueprint (never executed directly) |
| **Step** | Child of a Plan | Task within a Plan definition |
| **Workflow** | `task.source_plan_id` set | Running instance of a Plan |
| **Work Item** | Child of a Workflow | Task within a running Workflow |

### Task Lifecycle

```
Plan (blueprint)
  └── Tasks (step definitions)
        │
        ├── start  →  Persistent Workflow (keeps history)
        └── execute → Ephemeral Workflow (garbage collectible)
              │
              └── Tasks (work items)
```

### Ephemeral vs Persistent

| Type | Lifecycle | JSONL Export |
|------|-----------|--------------|
| **Persistent** | Kept forever | Exported |
| **Ephemeral** | Auto-cleaned after completion | Not exported |

Ephemeral workflows are useful for:
- One-shot operations that don't need permanent records
- Temporary exploratory work
- Reducing clutter in the task history

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rake test

# Run the CLI locally
bundle exec exe/tf
```

## License

MIT
