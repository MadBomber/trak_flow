# CLI Overview

TrakFlow provides a powerful command-line interface (`tf`) for managing tasks, plans, workflows, and dependencies.

## Basic Usage

```bash
tf COMMAND [SUBCOMMAND] [OPTIONS]
```

## Getting Help

```bash
# List all commands
tf help

# Help for a specific command
tf help create
tf help plan

# Subcommand help
tf plan help start
```

## Command Categories

| Category | Command | Description |
|----------|---------|-------------|
| **Tasks** | `tf create` | Create new tasks |
| | `tf list` | List tasks with filters |
| | `tf show` | Show task details |
| | `tf update` | Modify task properties |
| | `tf start` | Begin working on a task |
| | `tf close` | Complete a task |
| | `tf block` | Mark task as blocked |
| | `tf defer` | Postpone a task |
| | `tf reopen` | Reopen a closed task |
| **Plans** | `tf plan create` | Create a Plan blueprint |
| | `tf plan add` | Add step to a Plan |
| | `tf plan show` | View Plan details |
| | `tf plan start` | Create persistent Workflow |
| | `tf plan execute` | Create ephemeral Workflow |
| **Workflows** | `tf workflow list` | List Workflows |
| | `tf workflow show` | View Workflow progress |
| | `tf workflow summarize` | Summarize and close |
| | `tf workflow discard` | Discard ephemeral Workflow |
| | `tf workflow gc` | Garbage collect |
| **Dependencies** | `tf dep add` | Add dependency |
| | `tf dep remove` | Remove dependency |
| | `tf dep tree` | Show dependency tree |
| | `tf ready` | Find ready tasks |
| **Labels** | `tf label add` | Add label to task |
| | `tf label remove` | Remove label |
| | `tf label list` | List labels on task |
| | `tf label list-all` | List all labels |
| **Comments** | `tf comment add` | Add comment to task |
| | `tf comment list` | List task comments |
| **Admin** | `tf admin init` | Initialize TrakFlow |
| | `tf admin export` | Export to JSONL |
| | `tf admin import` | Import from JSONL |
| | `tf admin graph` | Generate dependency graph |
| | `tf admin analyze` | Analyze project |

## Common Options

Most commands support these options:

| Option | Description |
|--------|-------------|
| `--json` | Output in JSON format |
| `--quiet`, `-q` | Suppress non-essential output |
| `--verbose`, `-v` | Show detailed output |
| `--help`, `-h` | Show command help |

## Task ID Format

TrakFlow uses hash-based IDs:

```
tf-a1b2c3d4
```

You can use partial IDs if unique:

```bash
tf show tf-a1b    # Works if only one ID starts with tf-a1b
tf show a1b       # Also works without the tf- prefix
```

## Output Formats

### Default (Human-Readable)

```bash
tf list
```

```
ID          Title                 Status       Priority
tf-abc123   Fix login bug         in_progress  high
tf-def456   Add OAuth support     open         medium
tf-ghi789   Update documentation  open         low
```

### JSON Output

```bash
tf list --json
```

```json
[
  {"id": "tf-abc123", "title": "Fix login bug", "status": "in_progress", "priority": 1},
  {"id": "tf-def456", "title": "Add OAuth support", "status": "open", "priority": 2}
]
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TRAK_FLOW_DIR` | Data directory location | `.trak_flow` |
| `TRAK_FLOW_DEBUG` | Enable debug output | `false` |
| `TRAK_FLOW_COLOR` | Color output | `true` |

## Shell Completion

### Bash

```bash
# Add to ~/.bashrc
eval "$(tf completion bash)"
```

### Zsh

```bash
# Add to ~/.zshrc
eval "$(tf completion zsh)"
```

### Fish

```bash
# Add to ~/.config/fish/config.fish
tf completion fish | source
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Task not found |
| 4 | Validation error |

## Next Steps

- [Task Commands](task-commands.md) - Create and manage tasks
- [Plan Commands](plan-commands.md) - Work with Plans and Workflows
- [Dependency Commands](dependency-commands.md) - Manage task relationships
