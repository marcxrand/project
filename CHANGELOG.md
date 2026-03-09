# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.17] - 2026-02-27

### Changed
- Rework `graph_db` generator based on real-world usage
- Replace `AtomMap` custom Ecto type with plain `:map` field
- Replace `Node.changeset/3` with `changeset/2` using NodeTypes registry for type lookup
- Replace `conflict_target/0` callback with `conflict_keys/0` and add `put_constraints/1`
- Move `Member` node type from `Graph.NodeType.Member` to `Graph.Member`
- Use app's base `Schema` module in `Edge` and `Embedding` instead of inlining primary key config
- Add `NodeTypes` registry module for mapping type strings to modules

## [1.0.4] - 2026-01-04

### Fixed
- Fix `pgvector` task `BadMapError` by correctly accessing rewrite sources
- Fix `remove.agents_md` task to target `AGENTS.md` and check for existence

## [1.0.3] - 2026-01-04

### Changed
- Add documentation descriptions to all tasks
- Rename `UUIDv7` task to `Uuidv7` to fix naming conventions

## [1.0.1]

### Changed
- Add `agents_md` task that removes the `AGENTS.md` file
- Make `ex_sync` task optional in default setup

### Fixed
- Improve `pgvector` migration generation to reuse `pg_extensions` migration if present

## [1.0.0] - 2026

### Added

- Initial release
- Add tasks: Bun, Credo, DotenvParser, ExSync, Libcluster, MixTestWatch, Oban, ObanPro, ObanWeb, Pgvector, Quokka, RemixIcons, Tidewave, UUIDv7
- Remove tasks: DaisyUI, LiveTitleSuffix, RepoCredentials, ThemeToggle, Topbar
- Gen tasks: AppLayout, ClassFormatter, Gigalixir, GigalixirLibcluster, Gitignore, GraphDb, HomePage, PgExtensions, RepoConfig, Schema, Setup, SortDeps
- Composable setup task with optional flags
- Support for comma-separated task names
