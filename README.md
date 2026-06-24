# Codex Agent Bootstrap

This repository is a starter kit you can hand to a friend, team, or customer so it can become a well-structured Codex agent.

The design is intentionally two-step:

1. the root setup scripts prepare the global workbench
2. project initialization turns this folder into a concrete agent with its own identity, `AGENTS.md`, and project documents

## What This Repository Should Provide

- a fast path to a usable new agent
- global workbench tooling for macOS and Windows
- tool bundles installable in global or workspace mode
- structured onboarding for the real agent
- skills installable and updateable from original repositories
- a clean future project structure, with bootstrap internals living under `.bootstrap/`

## Quick Start

### 1. Prepare the Global Workbench

macOS:

```bash
chmod +x ./setup-mac.sh
./setup-mac.sh
```

Windows:

```powershell
.\setup-windows.ps1
```

These scripts install global workbench tooling only. They do **not** install Codex, project-specific files, or skills.

### 2. Open the Project in Codex

Open the folder in Codex and write:

```text
Please initialize this project as a customer agent.
```

The agent should then:

- read the bootstrap files first
- run an interview
- capture the project identity
- write the final `AGENTS.md`
- fill in `project.yaml`, `Memory.md`, `docs/`, and `automations/heartbeat/`

### 3. Install Tool Bundles Intentionally

The tool scripts ask for a target mode:

- `global`
- `workspace`

Available commands:

```bash
./scripts/install_tools.sh
./scripts/update_tools.sh
./scripts/list_tools.sh
```

Default bundles:

- `core`
- `documents`
- `pdf-images`
- `diagrams`
- `browser-automation`

### 4. Install Skills Intentionally

The skill scripts also ask for a target mode:

- `global`
- `workspace`

Available commands:

```bash
./scripts/install_skills.sh
./scripts/update_skills.sh
./scripts/list_skills.sh
```

Windows:

```powershell
.\scripts\install_skills.ps1
.\scripts\update_skills.ps1
.\scripts\list_skills.ps1
```

### 5. Optionally Wire In the IMAP MCP Server

If you want email access over IMAP as an MCP server, you can use the published `imap-mcp-server` directly through `npx`. This project includes a thin npm wrapper:

```bash
npm run setup
```

That command starts the web setup assistant from `imap-mcp-server`. There is also a direct MCP runner:

```bash
npm run imap:mcp
```

Notes:

- according to the upstream project, accounts are stored encrypted in `~/.imap-mcp/accounts.json`
- no external repository is committed into this bootstrap project
- the integration uses the published npm package and stays easy to update

## Structure

```text
bootstrap-agent/
├─ .bootstrap/
├─ AGENTS.md
├─ Memory.md
├─ README.md
├─ START_HERE.md
├─ project.yaml
├─ automations/
├─ docs/
├─ scripts/
├─ skills/
├─ setup-mac.sh
└─ setup-windows.ps1
```

## Responsibility Boundaries

### Global Workbench Setup

- `setup-mac.sh`
- `setup-windows.ps1`

These install the global standard bundles for the workbench. That includes native base tools for Git, Curl, `rg`, Draw.io, PDF/image work, and browser automation, plus a central Python workbench under `~/.codex/workbench/python` for Office and document tasks. The `documents` bundle also installs Node-based document packages such as `mammoth`, `docx`, `xlsx`, `pptxgenjs`, and `pdf-parse`. Daily-use wrappers such as `codex-python` and `codex-markitdown` are also created there, and the bundled document stack includes `pypdf`, `pymupdf`, and the native Homebrew `pymupdf` formula on macOS.

### Bootstrap Internals

- `.bootstrap/`

Contains templates, metadata, skill catalogs, and helper logic for initialization and skill management.

### Visible Project Commands

- `scripts/init-project.sh`
- `scripts/init-project.ps1`
- `scripts/install_tools.sh`
- `scripts/update_tools.sh`
- `scripts/list_tools.sh`
- `scripts/install_skills.sh`
- `scripts/install_skills.ps1`
- `scripts/update_skill.ps1`
- `scripts/update_skills.sh`
- `scripts/update_skills.ps1`
- `scripts/list_skills.sh`
- `scripts/list_skills.ps1`

These are thin entry points. The real logic lives under `.bootstrap/`.

Shortcut summary:

- `setup-*` prepares the machine
- `scripts/install_tools.*` manages tool bundles in global or workspace mode
- `scripts/init-project.*` initializes this project
- `.bootstrap/scripts/bootstrap-project-init.*` is only the internal implementation behind it

## Skill Principles

- tools are managed as bundles and can be `global` or `workspace` depending on the bundle
- skills always come from original repositories
- each skill install explicitly chooses `global` or `workspace`
- larger project-specific skill collections should live under `.bootstrap/skills-cache/` so the visible project root stays clean

## After Initialization

After the first onboarding run, the visible `AGENTS.md` belongs entirely to the concrete agent project.

The bootstrap-specific rules remain only under `.bootstrap/`, so the new user gets a clear, uncluttered project workspace.
