# Quick Start

This guide walks you through basic TrakFlow usage.

## Initialize Your Project

```bash
cd your-project
tf init
```

## Create Tasks

### Basic Task

```bash
tf create "Update documentation"
```

### Task with Options

```bash
tf create "Implement OAuth login" \
  --type feature \
  --priority 1 \
  --description "Add Google and GitHub OAuth providers"
```

### Shorthand Flags

```bash
tf create "Fix memory leak" -t bug -p 0 -d "Memory grows unbounded in worker"
```

## View Tasks

### List All Open Tasks

```bash
tf list
```

### Filter by Status

```bash
tf list --status in_progress
tf list -s blocked
```

### Filter by Type

```bash
tf list --type bug
tf list -T feature
```

### Show Task Details

```bash
tf show tf-abc123
```

## Update Tasks

### Start Working

```bash
tf start tf-abc123
```

### Mark as Blocked

```bash
tf block tf-abc123
```

### Close a Task

```bash
tf close tf-abc123 --reason "Implemented in PR #42"
```

## Work with Dependencies

### Add a Dependency

```bash
# Task A blocks Task B (B cannot start until A is done)
tf dep add tf-taskA tf-taskB
```

### View Dependencies

```bash
tf dep tree tf-abc123
```

### Find Ready Work

```bash
tf ready
```

This shows tasks with no open blockers.

## Create a Plan (Workflow Blueprint)

Plans are reusable templates for common workflows.

### Create a Plan

```bash
tf plan create "Release Checklist"
```

### Add Steps

```bash
tf plan add tf-plan1 "Run test suite"
tf plan add tf-plan1 "Update changelog"
tf plan add tf-plan1 "Bump version"
tf plan add tf-plan1 "Create release tag"
tf plan add tf-plan1 "Deploy to production"
```

### View Plan

```bash
tf plan show tf-plan1
```

## Execute a Workflow

### Persistent Workflow

Creates a workflow that persists in history:

```bash
tf plan start tf-plan1
```

### Ephemeral Workflow

Creates a one-shot workflow (auto-cleaned):

```bash
tf plan execute tf-plan1
```

### Monitor Workflow

```bash
tf workflow show tf-wf1
```

### Complete Workflow

```bash
tf workflow summarize tf-wf1 --summary "Released v1.2.0 successfully"
```

## Use Labels

### Add Labels

```bash
tf label add tf-abc123 "frontend"
tf label add tf-abc123 "urgent"
```

### Filter by Label

```bash
tf list --label frontend
```

### Remove Labels

```bash
tf label remove tf-abc123 "urgent"
```

## JSON Output

All commands support JSON output for scripting:

```bash
tf list --json
tf show tf-abc123 -j
tf ready -j
```

## Common Workflows

### Bug Triage

```bash
# Create bug
tf create "App crashes on startup" -t bug -p 0

# Start investigating
tf start tf-abc123

# Mark blocked if waiting on info
tf block tf-abc123

# Close when fixed
tf close tf-abc123 -r "Fixed null pointer in init"
```

### Feature Development

```bash
# Create feature
tf create "Add dark mode" -t feature -p 2

# Create subtasks
tf create "Design dark theme colors" --parent tf-feature1
tf create "Implement CSS variables" --parent tf-feature1
tf create "Add theme toggle" --parent tf-feature1

# Track dependencies
tf dep add tf-design tf-implement
tf dep add tf-implement tf-toggle
```

### Sprint Planning

```bash
# Create Plan for sprint workflow
tf plan create "Sprint Workflow"
tf plan add tf-plan1 "Sprint planning meeting"
tf plan add tf-plan1 "Daily standups"
tf plan add tf-plan1 "Sprint review"
tf plan add tf-plan1 "Retrospective"

# Start each sprint
tf plan start tf-plan1
```

## Next Steps

- [Configuration](configuration.md) - Customize settings
- [Core Concepts](../core-concepts/overview.md) - Understand the data model
- [CLI Reference](../cli/overview.md) - Complete command reference
