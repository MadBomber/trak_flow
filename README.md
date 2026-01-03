# TrakFlow

<table>
  <tr>
    <td width="40%">
      <img src="docs/assets/trak_flow.jpg" alt="TrakFlow" width="100%">
    </td>
    <td width="60%" valign="top">
      <strong>A distributed task tracking system for Robots with a DAG-based workflow engine.</strong>
      <br><br>
      TrakFlow helps Robots (what some might call AI agents) manage complex, multi-step work pipelines without losing track of what they need to do. It uses a dependency-aware task graph to codify plans and workflows, enabling Robots to handle lengthy operations reliably. Tasks are stored as git-tracked JSONL files with a SQLite cache for fast queries. The MCP server exposes your tasks to any Model Context Protocol compatible application.
      <br><br>
      <table>
        <tr>
          <td>:file_folder: Git-Backed</td>
          <td>:zap: SQLite Cache</td>
        </tr>
        <tr>
          <td>:id: Hash-Based IDs</td>
          <td>:link: Dependency Graph</td>
        </tr>
        <tr>
          <td>:robot: MCP Server</td>
          <td>:arrows_counterclockwise: Plans & Workflows</td>
        </tr>
      </table>
    </td>
  </tr>
</table>

<p align="center">
  <a href="https://madbomber.github.io/trak_flow/getting-started/installation/">Install</a> •
  <a href="https://madbomber.github.io/trak_flow/getting-started/quick-start/">Quick Start</a> •
  <a href="https://madbomber.github.io/trak_flow/">Documentation</a> •
  <a href="#examples">Examples</a>
</p>

<p align="center">
  <em>Under active development - watch out for frequent changes.</em>
</p>

---

## Features

### Git-Backed Persistence

Tasks are stored as human-readable JSONL files that live alongside your code. No external database server required. Every change is versioned through Git, giving you full history, branching, and collaboration capabilities. Roll back mistakes, review task history in PRs, and keep your project management data where it belongs—in your repository. The JSONL format is simple enough to edit by hand if needed, and plays nicely with standard Unix tools like `grep`, `jq`, and `awk`.

### Hash-Based IDs

TrakFlow generates unique task IDs using content hashing, eliminating merge conflicts when multiple Robots or team members create tasks simultaneously. No central ID server needed. IDs are deterministic and portable, making it safe to work offline and sync later without coordination overhead. Multiple Robots can work on the same project in parallel branches and merge their work cleanly.

### SQLite Cache

While JSONL provides persistence, a local SQLite database delivers blazing-fast queries with millisecond response times. Full-text search across task titles and descriptions, indexed lookups by status, priority, labels, and dependencies—all optimized for the rapid-fire queries that Robots generate during complex reasoning chains. The cache rebuilds automatically from JSONL on each session, so you never have to worry about sync issues.

### Dependency Graph

Model complex task relationships with a directed acyclic graph (DAG). Define blocking dependencies between tasks, mark related tasks for reference, and create parent-child hierarchies for organizing epics and subtasks. TrakFlow automatically detects cycles before they're created, identifies tasks that are ready for work (no open blockers), and can visualize your entire workflow as a graph. Perfect for multi-step pipelines where execution order matters.

### MCP Server

Expose your task data to Robots through the Model Context Protocol (MCP) standard. Compatible with Claude Desktop, VS Code extensions, and any MCP-enabled application. The server supports both STDIO transport for local development and IDE integrations, and HTTP/SSE transport for remote access and multi-client scenarios. Robots can create tasks, query by any field, update status, manage dependencies, and traverse the task graph—all through a clean tool-based API.

### Plans & Workflows

Define reusable workflow blueprints (Plans) and instantiate them as running Workflows. Perfect for repeatable processes like deployments, code reviews, release checklists, or onboarding procedures. Each Plan contains a sequence of task templates that get copied into a new Workflow when started. Choose persistent Workflows for audit trails and historical records, or ephemeral Workflows for temporary operations that auto-clean after completion to reduce clutter.

## Examples

The [`examples/`](examples/) directory contains working demos:

| Example | Description |
|---------|-------------|
| [`basic_usage.rb`](examples/basic_usage.rb) | Ruby library usage - creating tasks, managing dependencies, and querying the database |
| [`mcp/stdio_demo.rb`](examples/mcp/stdio_demo.rb) | MCP server with STDIO transport for local development and IDE integrations |
| [`mcp/http_demo.rb`](examples/mcp/http_demo.rb) | MCP server with HTTP/SSE transport for remote access and web applications |

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
### Using the CLI utility `tf`
#### Basic Commands

```bash
# Initialize TrakFlow in your project
tf init

# Displays config file with defaults which you can copy
tf config defaults > ~/.config/trak_flow/trak_flow.yml
# ... edit your configuration
tf config show # will show your configuration

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

#### Working with Plans and Workflows

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

### Task Types

- `bug` - Bug fixes
- `feature` - New features
- `task` - General tasks
- `epic` - Parent task containing sub-tasks
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
tf label add ID LABEL     # Add label to task
tf label remove ID LABEL  # Remove label
tf label list ID          # List labels for task
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

### Config Commands

```bash
tf config                 # Show bundled default configuration
tf config show            # Show current active configuration
tf config defaults        # Show bundled default configuration
tf config reset           # Reset configuration to defaults
tf config reset -g        # Reset global (XDG) config
tf config reset -f        # Force overwrite existing config
tf config get KEY         # Get a config value (e.g., 'mcp.port')
tf config set KEY VALUE   # Set a config value
tf config path            # Show configuration file paths
```

Configuration sources (lowest to highest priority):
1. Bundled defaults (ships with gem)
2. XDG user config (`~/.config/trak_flow/trak_flow.yml`)
3. Project config (`.trak_flow/config.yml`)
4. Environment variables (`TF_*`)

### Admin Commands

```bash
tf admin cleanup          # Clean up old closed tasks
tf admin compact          # Compact the database
tf admin graph            # Generate dependency graph (DOT/SVG)
tf admin analyze          # Analyze the task graph
```

## Configuration

TrakFlow uses the [anyway_config](https://github.com/palkan/anyway_config) gem for configuration management. Configuration is stored in YAML format.

### Configuration Files

| Priority | Location | Purpose |
|----------|----------|---------|
| 1 (lowest) | Bundled defaults | Ships with gem |
| 2 | `~/.config/trak_flow/trak_flow.yml` | User-wide settings |
| 3 | `.trak_flow/config.yml` | Project-specific settings |
| 4 (highest) | Environment variables | Runtime overrides |

### Example Configuration

```yaml
# ~/.config/trak_flow/trak_flow.yml
defaults:
  output:
    json: false
    stealth: false
  daemon:
    disabled: false
    auto_start: true
    flush_debounce: 5
  sync:
    auto_flush: true
    auto_import: true
    push: true
  create:
    require_description: false
  storage:
    jsonl_file: tasks.jsonl
  database:
    path: ~/.config/trak_flow/tf.db
  mcp:
    port: 3333
  actor: robot
```

### Environment Variables

Environment variables use the `TF_` prefix and double underscores for nested keys:

| Variable | Configuration Key | Example |
|----------|-------------------|---------|
| `TF_ACTOR` | `actor` | `TF_ACTOR=robot` |
| `TF_OUTPUT__JSON` | `output.json` | `TF_OUTPUT__JSON=true` |
| `TF_OUTPUT__STEALTH` | `output.stealth` | `TF_OUTPUT__STEALTH=true` |
| `TF_DAEMON__DISABLED` | `daemon.disabled` | `TF_DAEMON__DISABLED=true` |
| `TF_DAEMON__AUTO_START` | `daemon.auto_start` | `TF_DAEMON__AUTO_START=false` |
| `TF_SYNC__AUTO_FLUSH` | `sync.auto_flush` | `TF_SYNC__AUTO_FLUSH=false` |
| `TF_SYNC__PUSH` | `sync.push` | `TF_SYNC__PUSH=false` |
| `TF_STORAGE__JSONL_FILE` | `storage.jsonl_file` | `TF_STORAGE__JSONL_FILE=issues.jsonl` |
| `TF_DATABASE__PATH` | `database.path` | `TF_DATABASE__PATH=/tmp/tf.db` |
| `TF_MCP__PORT` | `mcp.port` | `TF_MCP__PORT=4000` |

## MCP Server

TrakFlow includes a Model Context Protocol (MCP) server that exposes task management to AI agents. Compatible with Claude Desktop, VS Code extensions, and any MCP-enabled application.

### Starting the Server

```bash
# STDIO transport (for local development and IDE integrations)
tf_mcp

# HTTP/SSE transport (for remote access and web applications)
tf_mcp --http --port 3333
```

### Available Tools

| Tool | Description |
|------|-------------|
| `task_create` | Create a new task |
| `task_list` | List tasks with filters |
| `task_show` | Get task details |
| `task_update` | Update task properties |
| `task_start` | Mark task as in progress |
| `task_close` | Complete a task |
| `task_block` | Mark task as blocked |
| `task_reopen` | Reopen a closed task |
| `plan_create` | Create a Plan blueprint |
| `plan_add_step` | Add a step to a Plan |
| `plan_start` | Create persistent Workflow from Plan |
| `plan_execute` | Create ephemeral Workflow from Plan |
| `dep_add` | Add dependency between tasks |
| `dep_remove` | Remove a dependency |
| `ready_tasks` | Find tasks with no blockers |
| `label_add` | Add label to a task |
| `label_remove` | Remove label from a task |
| `label_list` | List labels on a task |

### Available Resources

| URI | Description |
|-----|-------------|
| `trak_flow://tasks` | All tasks in the project |
| `trak_flow://ready` | Tasks ready to work on (no blockers) |
| `trak_flow://dependencies` | Dependency graph between tasks |
| `trak_flow://plans` | Plan blueprints and their Workflows |
| `trak_flow://labels` | All labels used in the project |
| `trak_flow://summary` | Project status overview |

### Claude Desktop Integration

Add to your Claude Desktop configuration (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "trak_flow": {
      "command": "tf_mcp",
      "args": []
    }
  }
}
```

## Architecture

```
.trak_flow/
├── trak_flow.db   # SQLite database (gitignored)
├── tasks.jsonl    # Git-tracked source of truth
├── config.yml     # Project configuration (YAML)
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
bundle exec bin/tf
```

## License

MIT
