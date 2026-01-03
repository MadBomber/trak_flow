# Configuration

TrakFlow stores configuration in `.trak_flow/config.json`.

## View Current Configuration

```bash
tf config list
```

## Get a Value

```bash
tf config get actor
```

## Set a Value

```bash
tf config set actor "username"
```

## Configuration Options

### General Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `actor` | string | `""` | Current user/agent identifier |
| `stealth` | boolean | `false` | Suppress status messages |
| `no_push` | boolean | `false` | Disable auto-push to git |

### Import Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `import.orphan_handling` | string | `"allow"` | How to handle orphaned parent references |

### Validation Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `validation.strict` | boolean | `false` | Enable strict validation |

### ID Generation Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `id_generator.min_hash_length` | integer | `8` | Minimum length for generated IDs |

### MCP Server Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `mcp.port` | integer | `3333` | Default HTTP port for MCP server |

## Example Configuration

```json
{
  "actor": "claude-agent",
  "stealth": false,
  "no_push": true,
  "import": {
    "orphan_handling": "allow"
  },
  "validation": {
    "strict": true
  },
  "id_generator": {
    "min_hash_length": 8
  },
  "mcp": {
    "port": 3333
  }
}
```

## Nested Configuration

Access nested values with dot notation:

```bash
# Get nested value
tf config get import.orphan_handling

# Set nested value
tf config set mcp.port 4000
```

## Environment Variables

Some settings can be overridden via environment variables:

| Variable | Description |
|----------|-------------|
| `TRAK_FLOW_ACTOR` | Override the actor setting |
| `TRAK_FLOW_STEALTH` | Set to "1" for stealth mode |

## Reset to Defaults

Delete the config file to reset:

```bash
rm .trak_flow/config.json
tf init  # Recreates with defaults
```

## Git Integration

The configuration file is git-tracked by default, allowing team members to share settings. The SQLite database is gitignored.

### Recommended .gitignore

```gitignore
.trak_flow/trak_flow.db
.trak_flow/trak_flow.db-*
```

This is created automatically by `tf init`.
