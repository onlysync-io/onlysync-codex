# Bootstrap Entry

This repository is a bootstrap template for capable Codex agents.

If this project has not been initialized for a concrete user yet, work in exactly this order:

1. Read [START_HERE.md](/Users/adrian/Desktop/Codex%20Setup/START_HERE.md).
2. Read [project.yaml](/Users/adrian/Desktop/Codex%20Setup/project.yaml).
3. Read [Memory.md](/Users/adrian/Desktop/Codex%20Setup/Memory.md).
4. Read [.bootstrap/README.md](/Users/adrian/Desktop/Codex%20Setup/.bootstrap/README.md).
5. Then read the bootstrap files referenced from `.bootstrap/README.md`.

## Bootstrap Rule

- Generic bootstrap logic lives under `.bootstrap/`.
- The visible scripts under `scripts/` are only entry points.
- During initialization, interview the user and build the real project from that conversation.
- After successful initialization, this file is replaced by a project-specific `AGENTS.md`.

## Onboarding Information to Collect

- user name
- agent name
- project name
- agent purpose and role
- country
- timezone
- language and tone
- sensitive boundaries and no-gos
- important tools, systems, or channels

## Skill Rule

- Tools and skills can be installed globally or in workspace mode.
- Tool bundles should prefer native installation; Python or Node should only fill real gaps.
- Skills always come from original repositories.
- Tool and skill installs must choose between `global` and `workspace`.

## Important Scripts

- `./setup-mac.sh`
- `./setup-windows.ps1`
- `./scripts/init-project.sh`
- `./scripts/init-project.ps1`
- `./scripts/install_tools.sh`
- `./scripts/install_tools.ps1`
- `./scripts/update_tools.sh`
- `./scripts/update_tools.ps1`
- `./scripts/list_tools.sh`
- `./scripts/list_tools.ps1`
- `./scripts/install_skills.sh`
- `./scripts/install_skills.ps1`
- `./scripts/update_skill.ps1`
- `./scripts/update_skills.sh`
- `./scripts/update_skills.ps1`
- `./scripts/list_skills.sh`
- `./scripts/list_skills.ps1`





<!-- CODEX_PROJECT_SKILLS_START -->
## Managed Project Skills

- `drawio-diagrams-enhanced`: Type `skill` | Target `/Users/adrian/Desktop/Codex Setup/skills/drawio-diagrams-enhanced` | Source `https://github.com/jgtolentino/insightpulse-odoo.git`
<!-- CODEX_PROJECT_SKILLS_END -->



<!-- CODEX_PROJECT_TOOL_BUNDLES_START -->
## Managed Project Tool Bundles

- `documents`: Target `/Users/adrian/Desktop/Codex Setup/.bootstrap/tools/documents` | Commands `/Users/adrian/Desktop/Codex Setup/.bootstrap/tools/bin/codex-python,/Users/adrian/Desktop/Codex Setup/.bootstrap/tools/bin/codex-markitdown` | Packages `python:openpyxl,python-docx,python-pptx,markitdown,pypdf,pymupdf`
  Note: Workspace mode installs the Python document tools locally. Pandoc and the Homebrew PyMuPDF formula remain globally preferred native tools.
<!-- CODEX_PROJECT_TOOL_BUNDLES_END -->
