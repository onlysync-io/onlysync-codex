# Project Memory

This file is the shared project memory for this bootstrap repository.

## Purpose

- keep bootstrap decisions traceable
- document the current repository state
- make later changes easier for future agents or maintainers

## Current State

- This repository is a bootstrap template for Codex agents.
- The global workbench is prepared through `.scripts/setup-mac.sh` and `.scripts/setup-windows.ps1`.
- Bootstrap internals live under `.bootstrap/`.
- Visible commands under `.scripts/` delegate to bootstrap logic.
- Root project documentation is intentionally reduced to `AGENTS.md`, `Memory.md`, and `Decisions.md`.
- Project automations live under `.bootstrap/automations/`.
- Project-local MCP servers live under `.mcp/`, with install metadata under `.bootstrap/mcp-installs/`.
- Skills are installed from original repositories.
- Skill installations distinguish between `global` and `project`.
- After initialization, the visible `AGENTS.md` is replaced with a project-specific version.

## Stable Decisions

- Tool bundles and skills may be installed in global or workspace mode.
- Native system tools stay globally preferred; Python and Node runtimes are created locally only where that makes sense.
- Codex itself is not installed by this repository.
- Larger project-specific skill collections should not clutter the visible project structure.
- The default `Heartbeat` automation is created during initialization.

### 2026-06-24 - Tool catalog and bundled workbench introduced

- Trigger: a request for a cross-platform, centralized workbench with selectable scope for tools and skills.
- Goal: stop treating tools as a fixed global list and instead manage them as bundles installable in `global` or `workspace` mode.
- Results:
  - New tool catalogs under `.bootstrap/lib/tool-catalog.sh` and `.bootstrap/lib/tool-catalog.ps1`.
  - New visible scripts for tool installation, update, and listing.
  - Default bundles: `core`, `documents`, `pdf-images`, `diagrams`, `browser-automation`.
  - Managed global installs are synchronized into `~/.codex/AGENTS.md` as compact reference blocks.

### 2026-06-24 - English output unification and managed skill inventory audit

- Trigger: a request to make all user-facing output English and clean up managed inventory reporting.
- Goal: unify project-facing text in English and keep `list_skills` metadata-driven while auditing real target paths.
- Results:
  - User-facing project text, templates, and managed AGENTS blocks were switched to English.
  - `list_skills` now reports `present` or `missing` based on the managed `TARGET_DIR`.
  - Duplicate metadata files are deduplicated by canonical filename, and stale extras are surfaced in list output.

### 2026-06-24 - Documents bundle now provisions Node document packages

- Trigger: a request to include the currently missing local document packages in `install_tools`.
- Goal: make the `documents` bundle provision both the Python document runtime and the Node-based document packages needed for extraction and generation tasks.
- Results:
  - `.bootstrap/lib/tool-catalog.ps1` now installs `mammoth`, `docx`, `xlsx`, `pptxgenjs`, and `pdf-parse` for global and project document bundle installs.
  - `.bootstrap/lib/tool-catalog.sh` mirrors the same behavior for macOS/Linux.
  - Bundle metadata and user-facing docs were updated to describe the expanded `documents` runtime.

### 2026-06-25 - Spillwave JIRA skill added to the managed catalog

- Trigger: a request to include `SpillwaveSolutions/jira` and install it globally.
- Goal: make the upstream JIRA skill available through the bootstrap's managed skill installer instead of requiring a manual install.
- Results:
  - `.bootstrap/lib/skill-catalog.sh` now supports a managed skill entry named `jira`.
  - `.scripts/README.md` now lists `jira` among the supported skill sources.
  - The global install metadata and `~/.codex/AGENTS.md` will be kept in sync through the normal installer flow.

### 2026-06-25 - Spillwave JIRA skill removed after comparison

- Trigger: a request to compare the two installed JIRA-related skills and keep the stronger one.
- Goal: avoid redundant JIRA skills and keep `jira-expert` as the single managed JIRA-oriented skill.
- Results:
  - The temporary managed `jira` catalog entry was removed from `.bootstrap/lib/skill-catalog.sh`.
  - The global install at `~/.codex/skills/jira` and its managed metadata were removed.
  - The managed global skills block in `~/.codex/AGENTS.md` was resynchronized.

### 2026-06-25 - MarkItDown skill promoted into managed bootstrap catalog

- Trigger: a request to keep the `markitdown` skill from SkillzWave, but manage it through the bootstrap instead of only through `skilz`.
- Goal: let the bootstrap own installation metadata, updates, and AGENTS synchronization for the selected MarkItDown skill.
- Results:
  - `.bootstrap/lib/skill-catalog.sh` now supports a managed `markitdown` skill sourced from `jimmc414/Kosmos`.
  - `.scripts/README.md` now lists `markitdown` among the supported skill sources.
  - Existing global installs at `~/.codex/skills/markitdown` can now be adopted into managed bootstrap metadata.

### 2026-06-30 - Root-only project docs and hidden operational folders

- Trigger: a request to remove redundant project docs and keep only the essential root files.
- Goal: consolidate customer context into `AGENTS.md`, move project decisions to `Decisions.md`, hide user-facing commands in `.scripts/`, and move project automations under `.bootstrap/automations/`.
- Results:
  - `docs/` was retired from the active project structure.
  - Root project docs are now `AGENTS.md`, `Memory.md`, and `Decisions.md`.
  - Visible entry points now live in `.scripts/`, including the setup scripts.
  - Project automations now live in `.bootstrap/automations/`.

### 2026-06-30 - MCP management added as a third install surface

- Trigger: a request to manage MCP servers alongside tools and skills, with global or project scope.
- Goal: add a dedicated install path for MCP servers, with project-local files under `.mcp/` and bootstrap metadata under `.bootstrap/mcp-installs/`.
- Results:
  - New scripts were added for `install_mcp`, `update_mcp`, and `list_mcps`.
  - MCP metadata now synchronizes into managed AGENTS blocks like tools and skills.
  - The first supported MCP source is `imap`, using upstream `npx` wrappers rather than a root `package.json`.

### 2026-07-01 - Apple app MCP catalog replaced the earlier iCloud MCP draft

- Trigger: a follow-up request to replace the earlier `MrGo2/icloud-mcp` draft with `griches/apple-mcp`.
- Goal: model Apple app MCPs in a way that matches the bootstrap surface better, with one managed MCP source per actual upstream server.
- Results:
  - `.bootstrap/lib/mcp-catalog.sh` now exposes `apple-calendar`, `apple-contacts`, `apple-mail`, `apple-maps`, `apple-messages`, `apple-notes`, and `apple-reminders` instead of a single `icloud` source.
  - The installer now creates lightweight `npx`-backed wrappers for each Apple MCP package published under `@griches`.
  - Global installs also upsert the matching `[mcp_servers.<name>]` block in `~/.codex/config.toml`.
  - Runtime notes per server document app-open requirements, Messages Full Disk Access, and optional safety flags such as `--read-only` and `--confirm-destructive`.

## Open Points

- Optionally add more skill sources to the catalog later.
- Optionally add more bootstrap utilities such as validation or upgrade helpers.
