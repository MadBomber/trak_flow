# Changelog

All notable changes to TrakFlow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

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
