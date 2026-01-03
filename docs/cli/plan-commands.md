# Plan & Workflow Commands

Commands for creating and managing Plans (blueprints) and Workflows (running instances).

## Plan Commands

### Create Plan

Create a new Plan blueprint.

```bash
tf plan create TITLE [OPTIONS]
```

#### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--description` | `-d` | Plan description |

#### Examples

```bash
tf plan create "Deploy to Production"

tf plan create "Release Checklist" -d "Standard release process"
```

### Add Step to Plan

Add a task definition to a Plan.

```bash
tf plan add PLAN_ID STEP_TITLE [OPTIONS]
```

#### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--description` | `-d` | Step description |
| `--type` | `-t` | Step type |
| `--priority` | `-p` | Step priority |

#### Examples

```bash
tf plan add tf-plan1 "Run test suite"
tf plan add tf-plan1 "Build Docker image"
tf plan add tf-plan1 "Deploy to staging"
tf plan add tf-plan1 "Run smoke tests"
tf plan add tf-plan1 "Deploy to production"
```

### Show Plan

Display Plan details and steps.

```bash
tf plan show PLAN_ID
```

#### Output

```
Plan: Deploy to Production [tf-plan1]
Status: open (blueprint)
Steps: 5

  [ ] Run test suite
  [ ] Build Docker image
  [ ] Deploy to staging
  [ ] Run smoke tests
  [ ] Deploy to production
```

### List Plans

List all Plan blueprints.

```bash
tf plan list [OPTIONS]
```

#### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--json` | | Output as JSON |

### Convert Task to Plan

Convert an existing task into a Plan.

```bash
tf plan convert TASK_ID
```

This sets `plan: true` on the task, making it a reusable blueprint.

### Start Workflow (Persistent)

Create a persistent Workflow from a Plan.

```bash
tf plan start PLAN_ID [OPTIONS]
```

#### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--title` | `-t` | Custom Workflow title |

#### Examples

```bash
tf plan start tf-plan1

tf plan start tf-plan1 --title "Deploy v1.2.0"
```

Persistent Workflows:
- Are exported to JSONL
- Appear in `tf workflow list`
- Kept after completion for history

### Execute Workflow (Ephemeral)

Create an ephemeral Workflow from a Plan.

```bash
tf plan execute PLAN_ID [OPTIONS]
```

#### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--title` | `-t` | Custom Workflow title |

#### Examples

```bash
tf plan execute tf-plan1

tf plan execute tf-plan1 --title "Quick deploy"
```

Ephemeral Workflows:
- NOT exported to JSONL
- Auto-cleaned after completion
- For temporary operations

## Workflow Commands

### List Workflows

List all Workflows.

```bash
tf workflow list [OPTIONS]
```

#### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--ephemeral` | `-e` | Only ephemeral Workflows |
| `--persistent` | `-p` | Only persistent Workflows |
| `--status` | `-s` | Filter by status |
| `--plan` | | Filter by source Plan |
| `--json` | | Output as JSON |

#### Examples

```bash
# All Workflows
tf workflow list

# Only ephemeral
tf workflow list -e

# Only in-progress
tf workflow list -s in_progress

# From a specific Plan
tf workflow list --plan tf-plan1
```

### Show Workflow

Display Workflow details and progress.

```bash
tf workflow show WORKFLOW_ID
```

#### Output

```
Workflow: Deploy v1.2.0 [tf-wf1]
Source Plan: tf-plan1
Type: Persistent
Status: in_progress

  [x] Run test suite
  [x] Build Docker image
  [~] Deploy to staging
  [ ] Run smoke tests
  [ ] Deploy to production

Progress: 2/5 completed
```

Legend:
- `[x]` - Completed
- `[~]` - In progress
- `[ ]` - Open
- `[!]` - Blocked

### Summarize Workflow

Add a summary and close a Workflow.

```bash
tf workflow summarize WORKFLOW_ID --summary "SUMMARY"
```

#### Examples

```bash
tf workflow summarize tf-wf1 --summary "Deployed v1.2.0 successfully"

tf workflow summarize tf-wf1 -s "Failed: staging smoke tests"
```

This:
1. Adds the summary to Workflow notes
2. Closes the Workflow
3. Records completion timestamp

### Discard Workflow

Delete an ephemeral Workflow.

```bash
tf workflow discard WORKFLOW_ID
```

!!! note
    Only ephemeral Workflows can be discarded.

### Garbage Collect

Clean up old ephemeral Workflows.

```bash
tf workflow gc [OPTIONS]
```

#### Options

| Option | Description |
|--------|-------------|
| `--older-than` | Age threshold (default: 7d) |
| `--dry-run` | Show what would be deleted |

#### Examples

```bash
# Default cleanup
tf workflow gc

# Clean Workflows older than 24 hours
tf workflow gc --older-than 24h

# Preview without deleting
tf workflow gc --dry-run
```

## Example: Complete Workflow

### 1. Create a Plan

```bash
tf plan create "Code Review Process"
tf plan add tf-plan1 "Check code style"
tf plan add tf-plan1 "Review logic"
tf plan add tf-plan1 "Check test coverage"
tf plan add tf-plan1 "Security review"
tf plan add tf-plan1 "Approve or request changes"
```

### 2. Start a Workflow

```bash
tf plan start tf-plan1 --title "Review PR #42"
```

### 3. Work Through Tasks

```bash
# Start first task
tf start tf-task1
tf close tf-task1

# Continue with remaining tasks
tf start tf-task2
tf close tf-task2

# ... etc
```

### 4. Complete the Workflow

```bash
tf workflow summarize tf-wf1 --summary "Approved with minor suggestions"
```

## Use Case: Release Process

```bash
# Create the Plan once
tf plan create "Release Process"
tf plan add tf-release "Update version in package.json"
tf plan add tf-release "Update CHANGELOG.md"
tf plan add tf-release "Run full test suite"
tf plan add tf-release "Build release artifacts"
tf plan add tf-release "Create GitHub release"
tf plan add tf-release "Deploy to production"
tf plan add tf-release "Announce on social media"

# For each release, start a Workflow
tf plan start tf-release --title "Release v2.0.0"

# Work through the checklist
tf start tf-task1
tf close tf-task1
# ...

# Summarize when done
tf workflow summarize tf-wf1 --summary "Released v2.0.0"
```
