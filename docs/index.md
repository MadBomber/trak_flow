# TrakFlow

A distributed task tracking system for AI agents with a DAG-based workflow engine.

TrakFlow helps AI agents manage complex, multi-step work pipelines without losing track of what they need to do. It uses a dependency-aware task graph to codify plans and workflows, enabling agents to handle lengthy operations reliably.

## Key Features

<div class="grid cards" markdown>

-   :material-git:{ .lg .middle } **Git-Backed Persistence**

    ---

    Tasks stored as JSONL files, versioned alongside your code. No external database required.

-   :material-identifier:{ .lg .middle } **Hash-Based IDs**

    ---

    Prevents merge conflicts when multiple agents work on the same project simultaneously.

-   :material-database:{ .lg .middle } **SQLite Cache**

    ---

    Fast indexed queries with millisecond response times for local operations.

-   :material-graph:{ .lg .middle } **Dependency Graph**

    ---

    Track blocking relationships and find tasks ready for work automatically.

-   :material-robot:{ .lg .middle } **MCP Server**

    ---

    Expose tasks to AI agents via the Model Context Protocol (MCP) standard.

-   :material-workflow:{ .lg .middle } **Plans & Workflows**

    ---

    Create reusable workflow blueprints and execute them as persistent or ephemeral workflows.

</div>

## Quick Example

```bash
# Initialize TrakFlow in your project
tf init

# Create a task
tf create "Implement user authentication" -t feature -p 1

# Create a Plan (workflow blueprint)
tf plan create "Deploy to Production"

# Add steps to the Plan
tf plan add tf-abc123 "Run tests"
tf plan add tf-abc123 "Build artifacts"
tf plan add tf-abc123 "Deploy"

# Execute the Plan as a Workflow
tf plan start tf-abc123

# Find tasks ready for work
tf ready
```

## Three Ways to Use TrakFlow

### 1. CLI Tool

Use `tf` commands to manage tasks from the terminal:

```bash
tf create "Fix login bug" -t bug -p 1
tf list --status open
tf close tf-abc123
```

### 2. Ruby Library

Integrate TrakFlow directly into your Ruby applications:

```ruby
require 'trak_flow'

TrakFlow.ensure_initialized!
db = TrakFlow::Storage::Database.new
db.connect

task = TrakFlow::Models::Task.new(
  title: "Automated task",
  type: "task",
  priority: 2
)
db.insert_task(task)
```

### 3. MCP Server

Expose TrakFlow to AI agents via the Model Context Protocol:

```bash
# Start the MCP server (STDIO transport)
tf_mcp

# Or HTTP transport
tf_mcp --http --port 3333
```

## Architecture Overview

```
.trak_flow/
├── trak_flow.db   # SQLite database (gitignored)
├── issues.jsonl   # Git-tracked source of truth
├── config.json    # Project configuration
└── .gitignore
```

TrakFlow uses a three-layer architecture:

1. **CLI/MCP Interface** - User and agent-facing commands
2. **SQLite Database** - Fast local queries and indexing
3. **JSONL Format** - Git-tracked persistence for collaboration

## Getting Started

<div class="grid cards" markdown>

-   :material-download:{ .lg .middle } **[Installation](getting-started/installation.md)**

    ---

    Install TrakFlow via RubyGems or from source

-   :material-rocket-launch:{ .lg .middle } **[Quick Start](getting-started/quick-start.md)**

    ---

    Get up and running in minutes

-   :material-cog:{ .lg .middle } **[Configuration](getting-started/configuration.md)**

    ---

    Customize TrakFlow for your project

</div>

## License

TrakFlow is released under the MIT License.
