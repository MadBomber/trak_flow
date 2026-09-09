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

- `tasks.jsonl` - Git-tracked task storage
- `trak_flow.db` - SQLite cache (gitignored)
- `config.yml` - Project configuration
- `.gitignore` - Ignores the database file

## Dependencies

TrakFlow depends on these gems (installed automatically):

| Gem | Purpose |
|-----|---------|
| `thor` | CLI framework |
| `sequel` | Database toolkit |
| `sqlite3` | Local database |
| `oj` | Fast JSON parsing |
| `anyway_config` | Configuration management |
| `pastel` | Terminal colors |
| `tty-table` / `tty-spinner` | Terminal formatting |
| `fast-mcp` | MCP server support |
| `debug_me` | Debug output |

### Optional: MCP HTTP transport

The MCP server's HTTP/SSE transport is opt-in — TrakFlow does not bundle a
web server. Add the `rackup` gem plus any Rack server that supports
`rack.hijack` (Puma, Falcon, WEBrick, ...) to your Gemfile:

```ruby
gem "rackup"
gem "puma"   # or falcon, webrick, ... — skip if your app already has one
```

If your application already runs its own Rack server, you don't need any of
this: mount `TrakFlow::Mcp::Server.new.rack_app` into it instead. The STDIO
transport (the default) needs nothing extra.

## Next Steps

- [Quick Start](quick-start.md) - Create your first tasks
- [Configuration](configuration.md) - Customize TrakFlow settings
