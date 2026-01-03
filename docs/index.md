# TrakFlow

<div class="grid" markdown>

<div markdown>

![TrakFlow](assets/trak_flow.jpg){ width="100%" }

</div>

<div markdown>

**A distributed task tracking system for Robots with a DAG-based workflow engine.**

TrakFlow helps Robots (what some might call AI agents) manage complex, multi-step work pipelines without losing track of what they need to do.

| | |
|---|---|
| :material-git: Git-Backed | :material-database: SQLite Cache |
| :material-identifier: Hash-Based IDs | :material-graph: Dependency Graph |
| :material-robot: MCP Server | :material-workflow: Plans & Workflows |

</div>

</div>

<p align="center" markdown>
[:material-download: Install](getting-started/installation.md){ .md-button .md-button--primary }
[:material-rocket-launch: Quick Start](getting-started/quick-start.md){ .md-button }
</p>

---

## Features

### Git-Backed Persistence

Tasks are stored as human-readable JSONL files that live alongside your code. No external database server required. Every change is versioned through Git, giving you full history, branching, and collaboration capabilities. Roll back mistakes, review task history in PRs, and keep your project management data where it belongs—in your repository.

### Hash-Based IDs

TrakFlow generates unique task IDs using content hashing, eliminating merge conflicts when multiple AI agents or team members create tasks simultaneously. No central ID server needed. IDs are deterministic and portable, making it safe to work offline and sync later without coordination overhead.

### SQLite Cache

While JSONL provides persistence, a local SQLite database delivers blazing-fast queries with millisecond response times. Full-text search, indexed lookups by status, priority, labels, and dependencies—all optimized for the rapid-fire queries that AI agents generate. The cache rebuilds automatically from JSONL on each session.

### Dependency Graph

Model complex task relationships with a directed acyclic graph (DAG). Define blocking dependencies, related tasks, and parent-child hierarchies. TrakFlow automatically detects cycles, identifies tasks ready for work (no open blockers), and visualizes your workflow as a graph. Perfect for multi-step pipelines where order matters.

### MCP Server

Expose your task data to AI agents through the Model Context Protocol (MCP) standard. Compatible with Claude Desktop, VS Code extensions, and any MCP-enabled application. Supports both STDIO transport for local development and HTTP/SSE for remote access. Agents can create, query, and update tasks programmatically.

### Plans & Workflows

Define reusable workflow blueprints (Plans) and instantiate them as running Workflows. Perfect for repeatable processes like deployments, code reviews, or onboarding checklists. Choose persistent Workflows for audit trails or ephemeral Workflows for temporary operations that auto-clean after completion.

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
