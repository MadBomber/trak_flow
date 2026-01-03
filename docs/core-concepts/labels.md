# Labels

Labels provide flexible categorization for tasks.

## Adding Labels

```bash
tf label add TASK_ID LABEL
```

### Examples

```bash
tf label add tf-abc123 "frontend"
tf label add tf-abc123 "urgent"
tf label add tf-abc123 "v2.0"
```

## Removing Labels

```bash
tf label remove TASK_ID LABEL
```

### Examples

```bash
tf label remove tf-abc123 "urgent"
```

## Viewing Labels

### Labels on a Task

```bash
tf label list TASK_ID
```

Output:

```
Labels for tf-abc123:
  - frontend
  - urgent
  - v2.0
```

### All Labels in Project

```bash
tf label list-all
```

Output:

```
All labels:
  - backend (3 tasks)
  - frontend (5 tasks)
  - urgent (2 tasks)
  - v2.0 (8 tasks)
```

## Filtering by Label

```bash
tf list --label frontend
tf list -l urgent
```

### Multiple Labels

```bash
tf list --label frontend --label urgent
```

This shows tasks with BOTH labels.

## Label Naming

### Conventions

Labels are case-sensitive strings. Common conventions:

| Category | Examples |
|----------|----------|
| Components | `frontend`, `backend`, `api`, `database` |
| Priority | `urgent`, `quick-win`, `stretch-goal` |
| Version | `v1.0`, `v2.0`, `next-release` |
| Team | `team-a`, `team-b`, `platform` |
| Status | `needs-review`, `blocked-external`, `ready-for-qa` |
| Type | `tech-debt`, `documentation`, `security` |

### Best Practices

1. **Use lowercase** - `frontend` not `Frontend`
2. **Use hyphens** - `needs-review` not `needs_review`
3. **Be consistent** - Agree on conventions with your team
4. **Keep it simple** - Fewer labels = easier to manage

## Use Cases

### Component Tracking

```bash
tf label add tf-abc123 "frontend"
tf label add tf-def456 "backend"
tf label add tf-ghi789 "api"

# Find all frontend tasks
tf list --label frontend
```

### Sprint Planning

```bash
tf label add tf-abc123 "sprint-42"
tf label add tf-def456 "sprint-42"

# Sprint backlog
tf list --label sprint-42 --status open
```

### Release Management

```bash
tf label add tf-abc123 "v2.0"
tf label add tf-def456 "v2.0"

# What's in v2.0?
tf list --label v2.0

# What's not done for v2.0?
tf list --label v2.0 --status open
```

### Priority Escalation

```bash
# Mark as urgent
tf label add tf-abc123 "urgent"

# Find all urgent tasks
tf list --label urgent

# De-escalate
tf label remove tf-abc123 "urgent"
```

### Workflow States

Labels can track custom workflow states:

```bash
tf label add tf-abc123 "needs-review"
tf label add tf-abc123 "in-qa"
tf label add tf-abc123 "approved"

# Find tasks needing review
tf list --label needs-review
```

## Labels vs Dependencies

| Use | Labels | Dependencies |
|-----|--------|--------------|
| Grouping | Yes | No |
| Blocking work | No | Yes |
| Filtering | Yes | Limited |
| Order/sequence | No | Yes |
| Multiple per task | Yes | Yes |

### When to Use Labels

- Categorization without blocking
- Cross-cutting concerns
- Temporary states
- Filtering/search

### When to Use Dependencies

- Task A must complete before Task B
- Sequential workflows
- Blocking relationships

## JSON Representation

Labels are stored as a separate entity with task associations:

```json
{
  "id": "lbl-123",
  "task_id": "tf-abc123",
  "name": "frontend",
  "created_at": "2024-01-15T10:00:00Z"
}
```

## Bulk Operations

### Add Label to Multiple Tasks

```bash
# Using shell loop
for id in tf-abc123 tf-def456 tf-ghi789; do
  tf label add $id "sprint-42"
done
```

### Remove Label from All Tasks

```bash
# Find all tasks with label and remove
tf list --label old-label --json | \
  jq -r '.[].id' | \
  xargs -I {} tf label remove {} "old-label"
```
