# Scripts

These visible scripts are user-facing commands. The real bootstrap logic lives under `.bootstrap/`.

## Available Scripts

- `init-project.sh`: visible entry point for project initialization on macOS/Linux
- `init-project.ps1`: visible entry point for project initialization on Windows
- `install_tools.sh`: installs tool bundles and asks for `global` or `workspace`
- `install_tools.ps1`: Windows entry point for the same tool logic
- `update_tools.sh`: updates managed tool bundles using the stored mode
- `update_tools.ps1`: Windows entry point for the same update logic
- `list_tools.sh`: shows the tool installations managed by this bootstrap
- `list_tools.ps1`: Windows entry point for the same listing logic
- `install_skills.sh`: installs skills from original repositories and asks for `global` or `workspace`
- `install_skills.ps1`: Windows entry point for the same skill-install logic
- `update_skill.sh`: updates already installed skills using the stored mode and source
- `update_skill.ps1`: Windows entry point for the same single-skill update logic
- `update_skills.sh`: alias for the same update logic
- `update_skills.ps1`: Windows entry point for the same update logic
- `list_skills.sh`: shows the managed skill inventory for this bootstrap
- `list_skills.ps1`: Windows entry point for the same listing logic

## Currently Supported Tool Bundles

- `core`
- `documents`
- `pdf-images`
- `diagrams`
- `browser-automation`
- `composio-cli`

## Currently Supported Skill Sources

- `financial-services`
- `marketingskills`
- `frontend-design`
- `humanizer`
- `ui-ux-pro-max`
- `drawio-diagrams-enhanced`
- `svg-precision`
- `pptx`
- `senior-architect`
- `brand-voice`
- `infographic-creation`
- `jira-expert`
- `confluence`

## Principles

- tool bundles and skills deliberately choose either `global` or `workspace`
- native system tools stay globally preferred; document-heavy Python or Node runtimes can be created locally when a bundle needs them
- the `documents` bundle provisions both Python document libraries and Node packages like `mammoth`, `docx`, `xlsx`, `pptxgenjs`, and `pdf-parse`
- project collections are stored under `.bootstrap/skills-cache/` so the visible structure stays clean
- internal bootstrap scripts intentionally use different names than the visible entry points, which makes the user surface easier to distinguish from the implementation
