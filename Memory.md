# Project Memory

This file is the shared project memory for this bootstrap repository.

## Purpose

- keep bootstrap decisions traceable
- document the current repository state
- make later changes easier for future agents or maintainers

## Current State

- This repository is a bootstrap template for Codex agents.
- The global workbench is prepared through `setup-mac.sh` and `setup-windows.ps1`.
- Bootstrap internals live under `.bootstrap/`.
- Visible scripts under `scripts/` delegate to bootstrap logic.
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

## Open Points

- Optionally add more skill sources to the catalog later.
- Optionally add more bootstrap utilities such as validation or upgrade helpers.
