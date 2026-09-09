# Changelog

All notable changes to TrakFlow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-09-08

### Added

- Real `Archspec.rb` (replacing the `architecture :rails` placeholder)
  encoding the gem's layering: leaf `support`/`config`, pure `models`,
  `storage` above models, `graph` over an injected db handle, and `cli`/
  `mcp` as peer interfaces that must not depend on each other. Enforced
  by the `archspec_check` quality gate.

### Changed

- The MCP HTTP transport is now Rack-server-agnostic. `Mcp::Server` no
  longer hard-codes Puma: `start_http` boots the transport through the
  generic `Rackup::Handler` interface, using (in priority order) the new
  `handler:` argument, the new `mcp.handler` config setting
  (`TF_MCP__HANDLER`), or Rackup's default lookup — which picks whatever
  Rack server the bundle already carries. Any server that supports
  `rack.hijack` works (Puma, Falcon, WEBrick, iodine).
- `Mcp::Server#rack_app` is now public API: applications that already run
  their own Rack server can mount the MCP transport into it (e.g.
  `map("/mcp") { run TrakFlow::Mcp::Server.new.rack_app }` in config.ru)
  instead of letting TrakFlow start a second server.
- The CLI `output` helpers now `yield` instead of capturing the block and
  calling it, avoiding a proc allocation on every command's output
  (Fasterer's block-vs-yield finding, applied across all 7 command
  classes). Its remaining suggestions are declined in `.fasterer.yml`
  with reasons: the while-loop rewrite trades readability for nothing in
  IO-bound code, and the fetch-with-block form conflicts with RuboCop's
  Style/RedundantFetchBlock for literal defaults.
- Docs: corrected stale filenames (`issues.jsonl` → `tasks.jsonl`,
  `config.json` → `config.yml`), MCP endpoint paths (`/mcp/sse`,
  `/mcp/messages`), default port (3333), and environment variable names
  (`TF_MCP__PORT`).

### Fixed

- `examples/cli_demo.sh` aborted before its final section: it referenced
  the pre-rename `.trak_flow/issues.jsonl` filename.

## [0.1.4] - 2026-09-08

### Changed

- `puma` and `rackup` are no longer gemspec dependencies. The MCP HTTP
  transport lazy-loads them and raises a clear error with instructions
  when they're missing; the stdio transport and the models/storage API
  never needed them. Consumers that run the HTTP transport must add
  `gem 'puma', '>= 7.2.1'` and `gem 'rackup'` to their own Gemfile.
  This keeps a web server (and its CVE surface — CVE-2026-47736 /
  CVE-2026-47737 affected puma ~> 6.0) out of consumers that only use
  TrakFlow as a task database.

## [0.1.3] - 2026-01-03

### Added

- Configurable JSONL storage filename via `storage.jsonl_file` config option
- New `storage` configuration section in defaults
- Environment variable `TF_STORAGE__JSONL_FILE` for runtime override
- Examples section in README with links to demo programs
- MCP Server section in README documenting all tools and resources
- `tf config` CLI commands documentation in README

### Changed

- Default JSONL filename changed from `issues.jsonl` to `tasks.jsonl`
- Configuration section in README updated to reflect YAML format and anyway_config usage
- Gemspec now uses `TrakFlow::VERSION` instead of hardcoded version string

### Fixed

- Architecture diagram in README now shows correct `config.yml` filename

## [0.1.2] - 2026-01-02

### Added

- MCP (Model Context Protocol) server for AI agent integration
  - STDIO transport for local development and IDE integrations
  - HTTP/SSE transport for remote access and web applications
  - Tools for task management (create, list, show, update, start, close, block, reopen)
  - Tools for plan/workflow management (create, start, execute)
  - Tools for dependencies and labels
  - Resources for reading task data (task list, ready tasks, dependencies, plans, labels)
- MCP demo examples
  - `examples/mcp/stdio_demo.rb` - STDIO transport demonstration
  - `examples/mcp/http_demo.rb` - HTTP/SSE transport demonstration
- Comprehensive documentation using MkDocs with Material theme
  - Getting Started guide (installation, quick start, configuration)
  - Core Concepts documentation (tasks, plans, workflows, dependencies, labels)
  - CLI Reference (task, plan, workflow, dependency, label, admin commands)
  - MCP Server documentation (overview, tools, resources, integration guide)
  - API Reference (Ruby library, Task model, Database API)

## [0.1.1] - 2026-01-01

### Added

- Initial TrakFlow implementation as a DAG-based workflow engine
- Task model with plan, workflow, and ephemeral flags
- SQLite storage with JSONL sync for git-friendly persistence
- Thor-based CLI (`tf`) with subcommands:
  - `plan` - manage workflow blueprints
  - `workflow` - manage running workflow instances
  - `dep` - manage task dependencies
  - `label` - manage task labels
  - `admin` - administrative commands (cleanup, compact, graph, analyze)
- Dependency graph with cycle detection
- Comprehensive test suite (276 tests, 84% coverage)

## [0.1.0] - 2026-01-01
- Initial concept and design
