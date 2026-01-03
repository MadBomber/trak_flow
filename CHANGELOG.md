# Changelog

All notable changes to TrakFlow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

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
