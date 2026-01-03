# MCP Tools Reference

This page documents all tools exposed by the TrakFlow MCP server.

## Task Management Tools

### task_create

Create a new task.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | string | Yes | Task title |
| `description` | string | No | Detailed description |
| `type` | string | No | Task type (task, bug, feature, epic, chore) |
| `priority` | integer | No | Priority 0-4 (default: 2) |
| `assignee` | string | No | Assigned user/agent |
| `parent_id` | string | No | Parent task ID |
| `plan` | boolean | No | Create as Plan blueprint |

#### Returns

```json
{
  "success": true,
  "task": {
    "id": "tf-abc123",
    "title": "New task",
    "status": "open",
    "priority": 2,
    "type": "task",
    "created_at": "2024-01-15T10:00:00Z"
  }
}
```

#### Example

```ruby
tool = client.tool("task_create")
result = tool.execute(
  title: "Implement user authentication",
  type: "feature",
  priority: 1,
  description: "Add login, logout, and session management"
)
```

### task_list

List tasks with optional filters.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `status` | string | No | Filter by status |
| `type` | string | No | Filter by type |
| `priority` | integer | No | Filter by priority |
| `assignee` | string | No | Filter by assignee |
| `label` | string | No | Filter by label |
| `parent_id` | string | No | Filter by parent |
| `limit` | integer | No | Max results |
| `offset` | integer | No | Skip results |

#### Returns

```json
{
  "tasks": [
    {"id": "tf-abc123", "title": "Task 1", "status": "open", "priority": 2},
    {"id": "tf-def456", "title": "Task 2", "status": "in_progress", "priority": 1}
  ],
  "count": 2,
  "total": 42
}
```

#### Example

```ruby
tool = client.tool("task_list")
result = tool.execute(status: "open", priority: 1)
```

### task_show

Get detailed information about a task.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Task ID |
| `include_deps` | boolean | No | Include dependencies |
| `include_labels` | boolean | No | Include labels |

#### Returns

```json
{
  "task": {
    "id": "tf-abc123",
    "title": "Implement feature",
    "description": "Detailed description",
    "status": "in_progress",
    "priority": 1,
    "type": "feature",
    "assignee": "claude",
    "created_at": "2024-01-15T10:00:00Z",
    "updated_at": "2024-01-16T14:30:00Z",
    "notes": "..."
  },
  "dependencies": {
    "blocked_by": ["tf-design1"],
    "blocks": ["tf-test1", "tf-docs1"]
  },
  "labels": ["backend", "security"]
}
```

### task_update

Update task properties.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Task ID |
| `title` | string | No | New title |
| `description` | string | No | New description |
| `priority` | integer | No | New priority |
| `type` | string | No | New type |
| `assignee` | string | No | New assignee |
| `notes` | string | No | Append to notes |

#### Returns

```json
{
  "success": true,
  "task": {
    "id": "tf-abc123",
    "title": "Updated title",
    "updated_at": "2024-01-16T15:00:00Z"
  }
}
```

### task_start

Mark a task as in progress.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Task ID |

#### Returns

```json
{
  "success": true,
  "task": {
    "id": "tf-abc123",
    "status": "in_progress"
  }
}
```

### task_close

Complete a task.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Task ID |
| `summary` | string | No | Completion summary |

#### Returns

```json
{
  "success": true,
  "task": {
    "id": "tf-abc123",
    "status": "closed",
    "closed_at": "2024-01-16T16:00:00Z"
  }
}
```

### task_block

Mark a task as blocked.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Task ID |
| `reason` | string | No | Blocking reason |

#### Returns

```json
{
  "success": true,
  "task": {
    "id": "tf-abc123",
    "status": "blocked"
  }
}
```

### task_reopen

Reopen a closed or deferred task.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Task ID |

#### Returns

```json
{
  "success": true,
  "task": {
    "id": "tf-abc123",
    "status": "open"
  }
}
```

## Plan & Workflow Tools

### plan_create

Create a Plan blueprint.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | string | Yes | Plan title |
| `description` | string | No | Plan description |

#### Returns

```json
{
  "success": true,
  "plan": {
    "id": "tf-plan123",
    "title": "Deploy Process",
    "plan": true
  }
}
```

### plan_add_step

Add a step to a Plan.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `plan_id` | string | Yes | Plan ID |
| `title` | string | Yes | Step title |
| `description` | string | No | Step description |

### plan_start

Create a persistent Workflow from a Plan.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `plan_id` | string | Yes | Plan ID |
| `title` | string | No | Custom Workflow title |

#### Returns

```json
{
  "success": true,
  "workflow": {
    "id": "tf-wf123",
    "source_plan_id": "tf-plan123",
    "ephemeral": false,
    "tasks": [
      {"id": "tf-task1", "title": "Step 1"},
      {"id": "tf-task2", "title": "Step 2"}
    ]
  }
}
```

### plan_execute

Create an ephemeral Workflow from a Plan.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `plan_id` | string | Yes | Plan ID |
| `title` | string | No | Custom Workflow title |

## Dependency Tools

### dep_add

Add a dependency between tasks.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `source_id` | string | Yes | Source task ID |
| `target_id` | string | Yes | Target task ID |
| `type` | string | No | Dependency type (blocks, related) |

#### Returns

```json
{
  "success": true,
  "dependency": {
    "source_id": "tf-abc123",
    "target_id": "tf-def456",
    "type": "blocks"
  }
}
```

### dep_remove

Remove a dependency.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `source_id` | string | Yes | Source task ID |
| `target_id` | string | Yes | Target task ID |

### ready_tasks

Find tasks with no open blockers.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | string | No | Filter by type |
| `priority` | integer | No | Filter by priority |
| `limit` | integer | No | Max results |

#### Returns

```json
{
  "tasks": [
    {"id": "tf-abc123", "title": "Ready task 1"},
    {"id": "tf-def456", "title": "Ready task 2"}
  ],
  "count": 2
}
```

## Label Tools

### label_add

Add a label to a task.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `task_id` | string | Yes | Task ID |
| `label` | string | Yes | Label name |

#### Returns

```json
{
  "success": true,
  "task_id": "tf-abc123",
  "label": "frontend"
}
```

### label_remove

Remove a label from a task.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `task_id` | string | Yes | Task ID |
| `label` | string | Yes | Label name |

### label_list

List labels on a task.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `task_id` | string | Yes | Task ID |

#### Returns

```json
{
  "task_id": "tf-abc123",
  "labels": ["frontend", "urgent", "v2.0"]
}
```

## Error Handling

All tools return errors in a consistent format:

```json
{
  "success": false,
  "error": {
    "code": "not_found",
    "message": "Task not found: tf-invalid"
  }
}
```

### Error Codes

| Code | Description |
|------|-------------|
| `not_found` | Resource not found |
| `validation_error` | Invalid parameters |
| `conflict` | Conflicting operation |
| `internal_error` | Server error |
