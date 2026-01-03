# MCP Resources Reference

Resources provide read-only access to TrakFlow data. AI agents can use resources to understand the current state of tasks without modifying anything.

## Available Resources

### Task List

**URI:** `trak_flow://tasks`
**Name:** Task List
**Description:** All tasks in the project

#### Content

```json
{
  "tasks": [
    {
      "id": "tf-abc123",
      "title": "Implement authentication",
      "status": "in_progress",
      "priority": 1,
      "type": "feature",
      "assignee": "claude",
      "created_at": "2024-01-15T10:00:00Z"
    },
    {
      "id": "tf-def456",
      "title": "Fix login bug",
      "status": "open",
      "priority": 0,
      "type": "bug"
    }
  ],
  "summary": {
    "total": 42,
    "by_status": {
      "open": 15,
      "in_progress": 5,
      "blocked": 3,
      "closed": 19
    }
  }
}
```

### Ready Tasks

**URI:** `trak_flow://ready`
**Name:** Ready Tasks
**Description:** Tasks with no open blockers, ready to work on

#### Content

```json
{
  "tasks": [
    {
      "id": "tf-abc123",
      "title": "Implement feature X",
      "priority": 1,
      "type": "feature"
    },
    {
      "id": "tf-def456",
      "title": "Fix critical bug",
      "priority": 0,
      "type": "bug"
    }
  ],
  "count": 2
}
```

### Dependencies

**URI:** `trak_flow://dependencies`
**Name:** Dependencies
**Description:** Dependency graph between tasks

#### Content

```json
{
  "dependencies": [
    {
      "source_id": "tf-design1",
      "target_id": "tf-implement1",
      "type": "blocks"
    },
    {
      "source_id": "tf-implement1",
      "target_id": "tf-test1",
      "type": "blocks"
    }
  ],
  "summary": {
    "total": 34,
    "by_type": {
      "blocks": 28,
      "related": 4,
      "parent-child": 2
    }
  }
}
```

### Plans

**URI:** `trak_flow://plans`
**Name:** Plans
**Description:** Plan blueprints and their Workflows

#### Content

```json
{
  "plans": [
    {
      "id": "tf-plan1",
      "title": "Deploy Process",
      "steps": [
        {"title": "Run tests"},
        {"title": "Build artifacts"},
        {"title": "Deploy to staging"},
        {"title": "Deploy to production"}
      ],
      "workflow_count": 3
    }
  ],
  "active_workflows": [
    {
      "id": "tf-wf1",
      "source_plan_id": "tf-plan1",
      "title": "Deploy v1.2.0",
      "progress": {
        "completed": 2,
        "total": 4
      }
    }
  ]
}
```

### Labels

**URI:** `trak_flow://labels`
**Name:** Labels
**Description:** All labels used in the project

#### Content

```json
{
  "labels": [
    {"name": "frontend", "task_count": 12},
    {"name": "backend", "task_count": 8},
    {"name": "urgent", "task_count": 3},
    {"name": "v2.0", "task_count": 15}
  ]
}
```

### Project Summary

**URI:** `trak_flow://summary`
**Name:** Project Summary
**Description:** Overview of project status

#### Content

```json
{
  "project": {
    "total_tasks": 47,
    "open_tasks": 12,
    "in_progress": 5,
    "blocked": 3,
    "closed": 27
  },
  "priorities": {
    "critical": 2,
    "high": 8,
    "medium": 25,
    "low": 10,
    "backlog": 2
  },
  "types": {
    "task": 30,
    "bug": 8,
    "feature": 5,
    "epic": 3,
    "chore": 1
  },
  "recent_activity": [
    {
      "task_id": "tf-abc123",
      "action": "closed",
      "timestamp": "2024-01-16T14:30:00Z"
    },
    {
      "task_id": "tf-def456",
      "action": "started",
      "timestamp": "2024-01-16T14:00:00Z"
    }
  ]
}
```

## Accessing Resources

### Using MCP Client

```ruby
# Get a resource by name
task_list = client.resource("Task List")

# Access the content
content = task_list.content
puts content["tasks"].length

# Or get by URI
ready = client.resource_by_uri("trak_flow://ready")
```

### Resource Properties

Each resource has these properties:

| Property | Description |
|----------|-------------|
| `uri` | Unique resource identifier |
| `name` | Human-readable name |
| `description` | What the resource contains |
| `mimeType` | Content type (application/json) |

## Resource Updates

Resources are read-only snapshots. To get updated data:

1. Request the resource again
2. Subscribe to updates via SSE (HTTP transport)

### SSE Updates (HTTP Transport)

When using HTTP/SSE transport, you can subscribe to resource updates:

```ruby
client.on_resource_update("trak_flow://tasks") do |content|
  puts "Tasks updated: #{content["tasks"].length} tasks"
end
```

## Using Resources with LLMs

Resources are designed to provide context to AI agents. Example prompt:

```
Based on the current task list, what should I work on next?

Task List:
{resource: trak_flow://tasks}

Ready Tasks:
{resource: trak_flow://ready}
```

The AI can analyze the data and recommend next steps.

## Resource Best Practices

### For AI Agents

1. **Start with summary** - Get the big picture first
2. **Check ready tasks** - Know what's actionable
3. **Review dependencies** - Understand blockers
4. **Cache wisely** - Resources are point-in-time snapshots

### For Integration

1. **Poll sparingly** - Resources don't change constantly
2. **Use SSE when available** - For real-time updates
3. **Handle errors gracefully** - Resources may be empty
4. **Respect rate limits** - Don't overload the server
