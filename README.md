# Codex Bootstrap

This repository is intended to live as `.codex` inside a customer code folder.

After `cdx init`, the only customer-facing project documents live one level above this repository:

- `../Agents.md`
- `../Memory.md`
- `../Decisions.md`

The hidden repository owns only the technical runtime:

```text
.codex/
  README.md
  project.yaml
  bin/
    cdx
    cdx.ps1
  bootstrap/
    commands/
    lib/
    templates/
    catalogs/
  state/
    tools/
    skills/
    mcps/
  runtime/
    tools/
    skills/
    mcps/
    automations/
```

## Main Flow

1. Clone this repository into the customer folder as `.codex`.
2. Run `./.codex/bin/cdx init`.
3. Answer the project questions.
4. Manage extensions through the same CLI:
   - `./.codex/bin/cdx add ...`
   - `./.codex/bin/cdx list ...`
   - `./.codex/bin/cdx update ...`

## Commands

```bash
./.codex/bin/cdx setup
./.codex/bin/cdx init
./.codex/bin/cdx add tool <name> --scope global|project
./.codex/bin/cdx add skill <name> --scope global|project
./.codex/bin/cdx add mcp <name> --scope global|project
./.codex/bin/cdx list [all|tools|skills|mcps] --scope global|project|both
./.codex/bin/cdx update [all|tools|skills|mcps] [name...] --scope global|project|both
```

## Rules

- `setup` prepares only the shared global workbench.
- `init` creates `../Agents.md`, `../Memory.md`, and `../Decisions.md` in the visible customer root.
- `state/` stores managed metadata only.
- `runtime/` stores project-local runtimes only.
- `bootstrap/` is internal implementation.
- Inventories are shown with `cdx list`, not through generated blocks inside `Agents.md`.

## MCP Notes

The managed macOS app MCP source is `macos-mcp`, backed by `krmj22/macos-mcp` and the npm package `mcp-macos`.

For a global install from this bootstrap:

```bash
./bin/cdx add mcp macos-mcp --scope global
~/.codex/mcp/macos-mcp/check.sh
~/.codex/mcp/macos-mcp/verify-jxa.sh
```

`check.sh` runs the upstream preflight. `verify-jxa.sh` runs the individual `osascript` probes so macOS can show the Automation prompts in a local GUI Codex session. For Mail and Messages, `~/.codex/mcp/macos-mcp/reveal-node-for-fda.sh` reveals the real Node binary and opens Full Disk Access settings.
