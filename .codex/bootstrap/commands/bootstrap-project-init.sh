#!/usr/bin/env bash
set -euo pipefail

bootstrap_init_project() {
  local root_dir customer_dir template_dir runtime_automation_dir timestamp today timezone
  local project_name user_name agent_name customer owner purpose role country language tone boundaries tools channels

  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  customer_dir="$(cd "$root_dir/.." && pwd)"
  template_dir="$root_dir/bootstrap/templates"
  runtime_automation_dir="$root_dir/runtime/automations/heartbeat"
  timestamp="$(date +"%Y-%m-%d %H:%M %Z")"
  today="$(date +%F)"

  prompt_default() {
    local label="$1"
    local default_value="${2:-}"
    local value

    if [[ -n "$default_value" ]]; then
      read -r -p "$label [$default_value]: " value
      printf '%s' "${value:-$default_value}"
    else
      read -r -p "$label: " value
      printf '%s' "$value"
    fi
  }

  confirm_overwrite() {
    local path="$1"
    local answer
    if [[ ! -f "$path" ]]; then
      return 0
    fi
    read -r -p "File exists: $path. Overwrite? [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]]
  }

  detect_timezone() {
    if [[ -n "${TZ:-}" ]]; then
      printf '%s' "$TZ"
    elif [[ -L /etc/localtime ]]; then
      readlink /etc/localtime | sed 's#^.*zoneinfo/##'
    elif [[ -f /etc/timezone ]]; then
      cat /etc/timezone
    else
      date +%Z
    fi
  }

  render_template() {
    local template_path="$1"
    local output_path="$2"
    local content

    if ! confirm_overwrite "$output_path"; then
      echo "Skipping existing file: $output_path"
      return 0
    fi

    content="$(cat "$template_path")"
    content="${content//__PROJECT_NAME__/$project_name}"
    content="${content//__USER_NAME__/$user_name}"
    content="${content//__AGENT_NAME__/$agent_name}"
    content="${content//__CUSTOMER__/$customer}"
    content="${content//__ROLE__/$role}"
    content="${content//__COUNTRY__/$country}"
    content="${content//__TIMEZONE__/$timezone}"
    content="${content//__LANGUAGE__/$language}"
    content="${content//__TONE__/$tone}"
    content="${content//__PURPOSE__/$purpose}"
    content="${content//__TOOLS__/$tools}"
    content="${content//__CHANNELS__/$channels}"
    content="${content//__BOUNDARIES__/$boundaries}"
    content="${content//__TIMESTAMP__/$timestamp}"
    content="${content//__DATE__/$today}"
    printf '%s\n' "$content" > "$output_path"
  }

  write_project_yaml() {
    cat > "$root_dir/project.yaml" <<EOF
bootstrap:
  name: "codex-agent-bootstrap"
  version: "0.3.0"
  initialized_at: "$timestamp"
  manifest: "bootstrap/manifest.json"

project:
  name: "$project_name"
  customer: "$customer"
  purpose: "$purpose"
  owner: "$owner"
  user_name: "$user_name"
  agent_name: "$agent_name"
  role: "$role"
  country: "$country"
  timezone: "$timezone"
  status: "initialized"
  language: "$language"
  customer_root: "$customer_dir"

agent:
  default_tone: "$tone"
  autonomy_level: "confirm_before_external_actions"
  risk_level: "medium"
  boundaries: "$boundaries"

memory:
  long_term_memory: "Memory MCP Server"
  visible_project_agents: "../Agents.md"
  visible_project_memory: "../Memory.md"
  global_memory: "~/.codex/Memory.md"

folders:
  visible_docs_root: ".."
  bin: "bin"
  bootstrap: "bootstrap"
  state: "state"
  runtime: "runtime"

extensions:
  scopes:
    - "global"
    - "project"
  supported_kinds:
    - "tool"
    - "skill"
    - "mcp"

heartbeat:
  enabled: true
  name: "Heartbeat"
  automation_path: "runtime/automations/heartbeat"
  timezone: "$timezone"
EOF
  }

  write_manifest() {
    cat > "$root_dir/bootstrap/manifest.json" <<EOF
{
  "bootstrap": {
    "name": "codex-agent-bootstrap",
    "version": "0.3.0"
  },
  "initialized": true,
  "initializedAt": "$timestamp",
  "entrypoints": [
    "bin/cdx",
    "bin/cdx.ps1"
  ],
  "managedAreas": [
    "bootstrap/",
    "state/",
    "runtime/"
  ],
  "notes": [
    "The repository is intended to live as .codex inside a customer folder.",
    "Visible project docs live one directory above the repository root.",
    "Tools, Skills, and MCPs are managed through a single cdx CLI."
  ]
}
EOF
  }

  write_heartbeat_readme() {
    mkdir -p "$runtime_automation_dir"
    cat > "$runtime_automation_dir/README.md" <<EOF
# Heartbeat

This automation folder is reserved for the default project heartbeat.

- Timezone: \`$timezone\`
- Created by: \`cdx init\`
EOF
  }

  timezone="$(detect_timezone)"
  project_name="$(prompt_default "Project name" "$(basename "$customer_dir")")"
  user_name="$(prompt_default "User name")"
  agent_name="$(prompt_default "Agent name" "Codex")"
  customer="$(prompt_default "Customer, team, or organization" "$user_name")"
  owner="$(prompt_default "Responsible person or team" "$user_name")"
  purpose="$(prompt_default "Agent purpose")"
  role="$(prompt_default "Agent role or focus" "AI coworker")"
  country="$(prompt_default "Country")"
  timezone="$(prompt_default "Timezone" "$timezone")"
  language="$(prompt_default "Language" "de")"
  tone="$(prompt_default "Tone" "freundlich, präzise, praktisch")"
  boundaries="$(prompt_default "Sensitive boundaries and no-gos" "No external changes without approval")"
  tools="$(prompt_default "Relevant systems" "GitHub, Google Workspace, Slack")"
  channels="$(prompt_default "Preferred channels" "Codex")"

  render_template "$template_dir/Agents.template.md" "$customer_dir/Agents.md"
  render_template "$template_dir/Memory.template.md" "$customer_dir/Memory.md"
  render_template "$template_dir/Decisions.template.md" "$customer_dir/Decisions.md"
  write_project_yaml
  write_manifest
  write_heartbeat_readme

  echo
  echo "Project initialized."
  echo "Visible project files:"
  echo "  $customer_dir/Agents.md"
  echo "  $customer_dir/Memory.md"
  echo "  $customer_dir/Decisions.md"
  echo
  echo "Next recommended commands:"
  echo "  ./.codex/bin/cdx add tool documents --scope project"
  echo "  ./.codex/bin/cdx add skill drawio-diagrams-enhanced --scope project"
  echo "  ./.codex/bin/cdx add mcp macos-mcp --scope global"
}
