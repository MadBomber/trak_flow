# Admin Commands

Commands for system administration, data management, and analysis.

## Initialize TrakFlow

Set up TrakFlow in a project directory.

```bash
tf admin init [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--force` | Overwrite existing configuration |
| `--dir` | Custom data directory (default: `.trak_flow`) |

### Examples

```bash
# Initialize in current directory
tf admin init

# Use custom directory
tf admin init --dir .tasks

# Reinitialize (overwrite)
tf admin init --force
```

### Created Structure

```
.trak_flow/
├── issues.jsonl    # Task data
├── trak_flow.db    # SQLite cache
└── config.json     # Configuration
```

## Export Data

Export tasks to JSONL format.

```bash
tf admin export [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--output`, `-o` | Output file (default: stdout) |
| `--format` | Output format (jsonl, json) |
| `--status` | Filter by status |
| `--type` | Filter by type |
| `--include-closed` | Include closed tasks |

### Examples

```bash
# Export to stdout
tf admin export

# Export to file
tf admin export -o backup.jsonl

# Export only open tasks
tf admin export --status open

# Export as JSON array
tf admin export --format json
```

## Import Data

Import tasks from JSONL format.

```bash
tf admin import FILE [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--merge` | Merge with existing data |
| `--replace` | Replace all existing data |
| `--dry-run` | Show what would be imported |

### Examples

```bash
# Import and merge
tf admin import backup.jsonl --merge

# Replace all data
tf admin import backup.jsonl --replace

# Preview import
tf admin import backup.jsonl --dry-run
```

## Generate Dependency Graph

Create a visual representation of task dependencies.

```bash
tf admin graph [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--format` | Output format: dot, svg, png (default: dot) |
| `--output`, `-o` | Output file |
| `--filter` | Filter expression |
| `--cluster` | Group by label or type |

### Examples

```bash
# DOT format to stdout
tf admin graph

# Generate SVG
tf admin graph --format svg -o deps.svg

# Generate PNG
tf admin graph --format png -o deps.png

# Filter by status
tf admin graph --filter "status=open"

# Cluster by type
tf admin graph --cluster type
```

### Using Graphviz

If you have Graphviz installed:

```bash
# Generate and render in one step
tf admin graph | dot -Tsvg -o deps.svg

# View immediately (macOS)
tf admin graph | dot -Tpng | open -f -a Preview
```

## Analyze Project

Analyze project health and statistics.

```bash
tf admin analyze [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--json` | Output as JSON |

### Output

```
TrakFlow Project Analysis
=========================

Tasks: 47
  - open: 12
  - in_progress: 5
  - blocked: 3
  - closed: 27

Types:
  - task: 30
  - bug: 8
  - feature: 5
  - epic: 3
  - chore: 1

Priorities:
  - critical (0): 2
  - high (1): 8
  - medium (2): 25
  - low (3): 10
  - backlog (4): 2

Dependencies:
  - Total relationships: 34
  - Orphan tasks: 5
  - Circular dependencies: 0

Labels:
  - Most used: frontend (12), backend (8), urgent (3)
  - Unused labels: 0

Plans:
  - Blueprints: 3
  - Active workflows: 2
  - Ephemeral workflows: 1

Health Score: 85/100
  - No circular dependencies ✓
  - Few blocked tasks ✓
  - Good label usage ✓
  - Recommendation: Close stale tasks (5 tasks open > 30 days)
```

## Rebuild Cache

Rebuild the SQLite cache from JSONL source.

```bash
tf admin rebuild
```

The cache is normally rebuilt automatically, but this forces a full rebuild.

## Archive Tasks

Archive old closed tasks.

```bash
tf admin archive [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--older-than` | Age threshold (default: 90d) |
| `--status` | Archive tasks with status |
| `--dry-run` | Show what would be archived |

### Examples

```bash
# Archive tasks closed > 90 days ago
tf admin archive

# Archive tasks closed > 30 days ago
tf admin archive --older-than 30d

# Preview
tf admin archive --dry-run
```

Archived tasks are marked with status `tombstone` and excluded from normal queries.

## Garbage Collection

Clean up ephemeral workflows and temporary data.

```bash
tf admin gc [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--older-than` | Age threshold (default: 7d) |
| `--dry-run` | Show what would be deleted |

### Examples

```bash
# Default cleanup
tf admin gc

# More aggressive
tf admin gc --older-than 24h

# Preview
tf admin gc --dry-run
```

## Configuration

### View Configuration

```bash
tf admin config
```

### Set Configuration

```bash
tf admin config KEY VALUE
```

### Examples

```bash
# View all settings
tf admin config

# Set default priority
tf admin config default_priority 2

# Set retention period
tf admin config gc_retention 7d
```

## Validate Data

Check data integrity.

```bash
tf admin validate
```

### Checks Performed

- JSONL syntax validity
- Required fields present
- Valid status values
- Valid priority values
- Valid type values
- Reference integrity (parent_id, dependencies)
- No circular dependencies

### Output

```
Validation Results
==================

✓ JSONL syntax: valid
✓ Required fields: present
✓ Status values: valid
✓ Priority values: valid
✓ Type values: valid
✓ Parent references: valid
✓ Dependency references: valid
✓ No circular dependencies

All checks passed!
```

## Backup and Restore

### Create Backup

```bash
tf admin export -o "backup-$(date +%Y%m%d).jsonl"
```

### Restore from Backup

```bash
tf admin import backup-20240115.jsonl --replace
tf admin rebuild
```

### Automated Backups

Add to your git workflow:

```bash
# .git/hooks/pre-commit
#!/bin/bash
cp .trak_flow/issues.jsonl .trak_flow/issues.jsonl.bak
```
