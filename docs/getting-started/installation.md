# Installation

## Requirements

- Ruby 3.2 or later
- Git (for version-controlled persistence)

## Install from RubyGems

```bash
gem install trak_flow
```

## Add to Your Gemfile

```ruby
gem 'trak_flow'
```

Then run:

```bash
bundle install
```

## Install from Source

```bash
git clone https://github.com/MadBomber/trak_flow.git
cd trak_flow
bundle install
bundle exec rake install
```

## Verify Installation

```bash
tf --version
```

You should see:

```
TrakFlow version 0.0.1
```

## Initialize a Project

Navigate to your project directory and run:

```bash
tf init
```

This creates a `.trak_flow/` directory with:

- `issues.jsonl` - Git-tracked task storage
- `trak_flow.db` - SQLite cache (gitignored)
- `config.json` - Project configuration
- `.gitignore` - Ignores the database file

## Dependencies

TrakFlow depends on these gems (installed automatically):

| Gem | Purpose |
|-----|---------|
| `thor` | CLI framework |
| `sqlite3` | Local database |
| `oj` | Fast JSON parsing |
| `pastel` | Terminal colors |
| `tty-table` | Table formatting |
| `fast_mcp` | MCP server support |
| `puma` | HTTP server for MCP |

## Next Steps

- [Quick Start](quick-start.md) - Create your first tasks
- [Configuration](configuration.md) - Customize TrakFlow settings
