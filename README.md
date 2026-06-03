# Codex Setup

Setup scripts for macOS and Windows to prepare a Codex-focused workstation with Composio, Remotion, Meta Ads CLI, and common media and automation tooling.

## Contents

- `setup-mac.sh`: Homebrew-based setup for macOS, including macOS-only MCP servers.
- `setup-windows.ps1`: `winget`/`npm`/`pip`/Git Bash-based setup for Windows.

## What Gets Installed

The scripts install or configure:

- Python 3
- Python 3.13 on macOS for Meta Ads CLI compatibility
- Node.js LTS and npm
- FFmpeg
- ImageMagick
- Ghostscript
- Git / Git Bash
- OpenAI Codex CLI
- Memory MCP server for Codex
- MarkItDown MCP server for Codex
- Apple Mail MCP server for Codex on macOS
- Apple Music MCP server for Codex on macOS
- Apple Calendar MCP server for Codex on macOS
- ChatGPT desktop app where supported
- `pnpm` for local Node-based MCP servers
- `pipx` for global Python CLI installs
- Python packages: `holidays`, `pillow`, `rembg`, `markitdown-mcp`
- Composio CLI
- Meta Ads CLI via `pipx install meta-ads`
- Several Codex skills, including Remotion, Composio, brand, and design-related skills

After installation, restart Codex so newly installed skills and MCP configuration are picked up.

## Windows Setup

### Requirement

Windows requires `winget`. If it is missing, install **App Installer** from the Microsoft Store and restart PowerShell.

### Run The Script

Open PowerShell in this project folder and run:

```powershell
.\setup-windows.ps1
```

If PowerShell blocks script execution, use one of these options.

### Option A: Allow Only For This Session

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup-windows.ps1
```

### Option B: Allow For Your User

```powershell
Unblock-File .\setup-windows.ps1
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
.\setup-windows.ps1
```

### Option C: Run Directly With Bypass

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

## macOS Setup

Open Terminal in this project folder and run:

```bash
chmod +x ./setup-mac.sh
./setup-mac.sh
```

If Homebrew is missing, the script installs it automatically.

## Composio

The setup installs Composio CLI. In a new terminal, sign in and verify:

```bash
composio login
composio whoami
```

Official toolkit docs:

https://docs.composio.dev/toolkits

The scripts intentionally reinstall Composio cleanly by removing only the local Composio binary and version marker files in `~/.composio`. Existing login, user, and config files are preserved.

Typical CLI workflow:

```bash
composio search "gmail"
composio link gmail
composio execute "<TOOL_SLUG>" -d '{"key":"value"}'
```

If a project uses the Composio SDK directly:

```bash
composio init
```

## Meta Ads CLI

This project uses the official Meta Ads CLI, not a Meta Ads MCP server.

The setup installs the CLI globally with `pipx`:

```bash
pipx install --python python3.13 meta-ads
```

On macOS, the setup installs `python@3.13` and `pipx`, then installs `meta-ads` against Python 3.13 because the package currently publishes compatible wheels for CPython 3.12/3.13 and this avoids the common Homebrew `pip` / PEP 668 issue.

On Windows, the setup installs the CLI through `pipx` using Python 3.12.

If `pipx` reports that `~/.local/bin` is not on `PATH`, run:

```bash
pipx ensurepath
```

Then restart your terminal.

Official Meta setup reference:

https://developers.facebook.com/documentation/ads-commerce/ads-ai-connectors/ads-cli/setup/get-started

Supplementary third-party guide:

https://www.get-ryze.ai/blog/meta-cli-command-line-tool-for-meta-ads-automation

Note: the Ryze article is useful for ideas and workflow examples, but the official Meta documentation and the official PyPI package `meta-ads` remain the source of truth for this project.

## Project-Specific CLI Paths

Use these generic path patterns in project instructions:

```text
Meta Ads CLI: ~/.local/pipx/venvs/meta-ads/bin/meta
Composio CLI: ~/.composio/composio
```

For Meta Ads work in this project, prefer the Meta Ads CLI at:

```text
~/.local/pipx/venvs/meta-ads/bin/meta
```

For other Composio access in this project, prefer the local Composio CLI at:

```text
~/.composio/composio
```

Only use another path or integration method if the relevant CLI is demonstrably unavailable.

## Remotion

Remotion is usually created per project. Start a new Remotion project with:

```bash
npx create-video@latest
```

Docs: https://www.remotion.dev/docs

## Design Skills

The setup installs two focused skills from `nextlevelbuilder/ui-ux-pro-max-skill` in addition to `ui-ux-pro-max`:

- `ckm:design`
- `ckm:banner-design`

This keeps UI/UX decisions, brand assets, and concrete creative production separated.

## MarkItDown MCP

The setup installs `markitdown-mcp` and writes it into `~/.codex/config.toml`.

On macOS, the script uses a dedicated virtual environment so Homebrew Python is not modified by global package installs:

```toml
[mcp_servers.markitdown]
command = "/Users/<your-user>/.codex/venvs/python-tools/bin/markitdown-mcp"
enabled = true
```

## macOS-only MCP Servers

On macOS, the setup also installs Apple Mail MCP, Apple Music MCP, and Apple Calendar MCP under `~/.codex/mcp/` and registers them in `~/.codex/config.toml`.

## Outlook MCP

The linked `marlonluo2018/outlook-mcp-server` is Windows-only. It depends on Outlook desktop and Windows COM APIs. For a cross-platform approach, a Microsoft Graph-based MCP is more appropriate.

## After Setup

1. Restart Terminal or PowerShell.
2. Restart Codex so MCP configuration and skills are reloaded.
3. Optionally verify:

```bash
codex --version
node --version
npm --version
composio whoami
~/.local/pipx/venvs/meta-ads/bin/meta --help
```
