# Changelog

All notable changes to TrakFlow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [0.0.2] - 2026-01-02

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

## [0.0.1] - 2026-01-02

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
