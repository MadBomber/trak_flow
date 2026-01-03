# Label Commands

Commands for managing task labels.

## Add Label

Add a label to a task.

```bash
tf label add TASK_ID LABEL
```

### Examples

```bash
tf label add tf-abc123 "frontend"
tf label add tf-abc123 "urgent"
tf label add tf-abc123 "v2.0"
```

## Remove Label

Remove a label from a task.

```bash
tf label remove TASK_ID LABEL
```

### Examples

```bash
tf label remove tf-abc123 "urgent"
```

## List Labels

### Labels on a Task

```bash
tf label list TASK_ID
```

#### Output

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

#### Output

```
All labels:
  - backend (3 tasks)
  - frontend (5 tasks)
  - urgent (2 tasks)
  - v2.0 (8 tasks)
```

## Filter by Label

Use `--label` with the list command:

```bash
# Single label
tf list --label frontend
tf list -l urgent

# Multiple labels (AND)
tf list --label frontend --label urgent
```

Multiple labels shows tasks with ALL specified labels.

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

### Rename a Label

```bash
# Remove old, add new
tf list --label old-name --json | \
  jq -r '.[].id' | \
  while read id; do
    tf label remove $id "old-name"
    tf label add $id "new-name"
  done
```

## Labels vs Other Features

| Use Case | Use Labels | Use Dependencies | Use Priority |
|----------|------------|------------------|--------------|
| Grouping | Yes | No | No |
| Blocking work | No | Yes | No |
| Filtering | Yes | Limited | Yes |
| Order/sequence | No | Yes | Yes |
| Urgency | Maybe | No | Yes |
| Categories | Yes | No | No |

### When to Use Labels

- Categorization without blocking
- Cross-cutting concerns
- Temporary states
- Filtering/search
- Organizing by component, team, or version

### When NOT to Use Labels

- Representing task priority (use priority field)
- Blocking relationships (use dependencies)
- Hierarchical organization (use parent_id)
