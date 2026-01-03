# Core Concepts Overview

TrakFlow is built around a few key concepts that work together to provide flexible task management.

## The Task Model

Everything in TrakFlow is a **Task**. Tasks serve multiple roles depending on their flags:

```mermaid
graph TD
    A[Task] --> B{plan?}
    B -->|true| C[Plan Blueprint]
    B -->|false| D{source_plan_id?}
    D -->|set| E[Workflow Instance]
    D -->|not set| F[Regular Task]

    C --> G[Contains Steps]
    E --> H[Contains Work Items]
    F --> I[Standalone Task]
```

| Role | Identification | Description |
|------|----------------|-------------|
| **Task** | Default | A unit of work to be completed |
| **Plan** | `task.plan? == true` | A reusable workflow blueprint |
| **Step** | Child of a Plan | A task definition within a Plan |
| **Workflow** | `task.source_plan_id` set | A running instance of a Plan |
| **Work Item** | Child of a Workflow | A task within a running Workflow |

## Task Lifecycle

```mermaid
stateDiagram-v2
    [*] --> open: Create
    open --> in_progress: Start
    open --> blocked: Block
    open --> deferred: Defer
    in_progress --> blocked: Block
    in_progress --> closed: Close
    blocked --> open: Unblock
    blocked --> in_progress: Unblock & Start
    deferred --> open: Reopen
    closed --> open: Reopen
    closed --> tombstone: Archive
    tombstone --> [*]
```

### Statuses

| Status | Description |
|--------|-------------|
| `open` | Ready to work on |
| `in_progress` | Currently being worked on |
| `blocked` | Waiting on something |
| `deferred` | Postponed for later |
| `closed` | Completed |
| `tombstone` | Archived (permanent) |
| `pinned` | Highlighted for visibility |

## Dependency Graph

Tasks can depend on other tasks. TrakFlow maintains a dependency graph to:

1. **Track blockers** - Know what's preventing work
2. **Find ready work** - Identify tasks with no open blockers
3. **Visualize relationships** - Understand task connections

```mermaid
graph LR
    A[Design API] -->|blocks| B[Implement API]
    B -->|blocks| C[Write Tests]
    B -->|blocks| D[Update Docs]
    C -->|blocks| E[Deploy]
    D -->|blocks| E
```

### Dependency Types

| Type | Description |
|------|-------------|
| `blocks` | Hard dependency (default) |
| `related` | Soft link for reference |
| `parent-child` | Hierarchical relationship |
| `discovered-from` | Traceability link |

## Plans and Workflows

Plans are reusable workflow templates. When executed, they create Workflows.

```mermaid
graph TB
    subgraph Plan [Plan: Deploy Checklist]
        P1[Run Tests]
        P2[Build Artifacts]
        P3[Deploy Staging]
        P4[Deploy Production]
    end

    subgraph Workflow [Workflow: Deploy v1.2]
        W1[Run Tests ✓]
        W2[Build Artifacts ✓]
        W3[Deploy Staging ~]
        W4[Deploy Production]
    end

    Plan -->|start| Workflow
```

### Workflow Types

| Type | Created By | Lifecycle | JSONL Export |
|------|------------|-----------|--------------|
| **Persistent** | `tf plan start` | Kept forever | Yes |
| **Ephemeral** | `tf plan execute` | Auto-cleaned | No |

## Labels

Labels provide flexible categorization:

```bash
tf label add tf-abc123 "frontend"
tf label add tf-abc123 "urgent"
tf label add tf-abc123 "v2.0"
```

Labels can represent:
- **Components**: `frontend`, `backend`, `api`
- **Priority markers**: `urgent`, `quick-win`
- **Versions**: `v1.0`, `v2.0`
- **States**: `needs-review`, `blocked-external`

## Data Storage

TrakFlow uses a dual-storage approach:

```
.trak_flow/
├── issues.jsonl    # Source of truth (git-tracked)
├── trak_flow.db    # Fast cache (gitignored)
└── config.json     # Settings (git-tracked)
```

### JSONL Format

Human-readable, one task per line:

```json
{"id":"tf-abc123","title":"Fix bug","status":"open","priority":1}
{"id":"tf-def456","title":"Add feature","status":"in_progress","priority":2}
```

### SQLite Cache

Provides:
- **Fast queries** - Millisecond response times
- **Indexing** - By status, priority, labels
- **Full-text search** - Search task content

The cache is rebuilt automatically from JSONL on each session.

## Hash-Based IDs

TrakFlow generates IDs using content hashes:

```
tf-a1b2c3d4
```

Benefits:
- **No collisions** - Multiple agents can create tasks simultaneously
- **Merge-friendly** - Git merges work without conflicts
- **Deterministic** - Same content = same ID (for deduplication)

## Next Steps

- [Tasks](tasks.md) - Deep dive into task properties
- [Plans & Workflows](plans-workflows.md) - Workflow automation
- [Dependencies](dependencies.md) - Managing task relationships
