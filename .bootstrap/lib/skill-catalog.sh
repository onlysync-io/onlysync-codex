#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$BOOTSTRAP_ROOT/.." && pwd)"
PROJECT_SKILLS_DIR="$PROJECT_ROOT/skills"
PROJECT_CACHE_DIR="$BOOTSTRAP_ROOT/skills-cache"
PROJECT_STATE_DIR="$BOOTSTRAP_ROOT/skill-installs"
GLOBAL_SKILLS_DIR="$HOME/.codex/skills"
GLOBAL_COLLECTIONS_DIR="$HOME/.codex/skills/_vendor"
GLOBAL_AGENTS_FILE="$HOME/.codex/AGENTS.md"
PROJECT_AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"

SUPPORTED_SKILLS=(
  "financial-services"
  "marketingskills"
  "frontend-design"
  "humanizer"
  "ui-ux-pro-max"
  "drawio-diagrams-enhanced"
  "svg-precision"
  "pptx"
  "senior-architect"
  "brand-voice"
  "infographic-creation"
  "jira-expert"
  "confluence"
)

ensure_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: Required command is missing: $command_name" >&2
    exit 1
  fi
}

ensure_base_dirs() {
  mkdir -p "$PROJECT_SKILLS_DIR" "$PROJECT_CACHE_DIR" "$PROJECT_STATE_DIR"
}

canonical_skill_metadata_path_for() {
  local skill_name="$1"
  local mode="$2"
  printf '%s/%s--%s.env' "$PROJECT_STATE_DIR" "$mode" "$skill_name"
}

decode_metadata_value() {
  local raw_value="$1"

  if [[ "$raw_value" == \'*\' && "$raw_value" == *\' ]]; then
    printf '%s' "${raw_value:1:${#raw_value}-2}"
  else
    printf '%s' "$raw_value" | sed -e 's/\\ / /g' -e 's/\\,/,/g' -e 's/\\|/|/g' -e 's/\\\\/\\/g'
  fi
}

load_skill_metadata() {
  local metadata_file="$1"
  local key raw_value decoded_value

  unset NAME MODE TYPE REPO_URL TARGET_DIR INSTALLED_AT UPDATED_AT
  while IFS='=' read -r key raw_value; do
    [[ -n "$key" ]] || continue
    decoded_value="$(decode_metadata_value "$raw_value")"
    printf -v "$key" '%s' "$decoded_value"
  done < "$metadata_file"
}

name_is_listed() {
  local needle="$1"
  shift
  local entry

  for entry in "$@"; do
    if [[ "$entry" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

find_selected_key_index() {
  local needle="$1"
  local index=0

  for entry in "${SELECTED_SKILL_METADATA_KEYS[@]-}"; do
    if [[ "$entry" == "$needle" ]]; then
      printf '%s' "$index"
      return 0
    fi
    index=$((index + 1))
  done
  return 1
}

list_supported_skills() {
  printf '%s\n' "${SUPPORTED_SKILLS[@]}"
}

usage_install() {
  cat <<'EOF'
Usage:
  ./scripts/install_skills.sh global all
  ./scripts/install_skills.sh workspace drawio-diagrams-enhanced
  ./scripts/install_skills.sh all
  ./scripts/install_skills.sh frontend-design humanizer
  ./scripts/install_skills.sh ui-ux-pro-max pptx jira-expert
  ./scripts/install_skills.sh --mode global all
EOF
}

usage_update() {
  cat <<'EOF'
Usage:
  ./scripts/update_skill.sh all
  ./scripts/update_skill.sh financial-services
  ./scripts/update_skill.sh ui-ux-pro-max pptx jira-expert
EOF
}

prompt_mode() {
  local input
  while true; do
    read -r -p "Choose skill mode [global/workspace]: " input
    case "$input" in
      global)
        printf 'global'
        return
        ;;
      workspace|projektbezogen|projekt|project)
        printf 'project'
        return
        ;;
    esac
    echo "Please enter 'global' or 'workspace'."
  done
}

metadata_path_for() {
  local skill_name="$1"
  local mode="$2"
  canonical_skill_metadata_path_for "$skill_name" "$mode"
}

write_install_metadata() {
  local skill_name="$1"
  local mode="$2"
  local source_type="$3"
  local repo_url="$4"
  local target_dir="$5"
  local installed_at

  installed_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  {
    printf 'NAME=%q\n' "$skill_name"
    printf 'MODE=%q\n' "$mode"
    printf 'TYPE=%q\n' "$source_type"
    printf 'REPO_URL=%q\n' "$repo_url"
    printf 'TARGET_DIR=%q\n' "$target_dir"
    printf 'INSTALLED_AT=%q\n' "$installed_at"
    printf 'UPDATED_AT=%q\n' "$installed_at"
  } > "$(metadata_path_for "$skill_name" "$mode")"
}

write_source_metadata() {
  local target_dir="$1"
  local name="$2"
  local source_type="$3"
  local repo_url="$4"

  mkdir -p "$target_dir"
  {
    printf 'NAME=%q\n' "$name"
    printf 'TYPE=%q\n' "$source_type"
    printf 'REPO_URL=%q\n' "$repo_url"
    printf 'UPDATED_AT=%q\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  } > "$target_dir/.skill-source.env"
}

target_contains_skill_files() {
  local target_dir="$1"

  [[ -d "$target_dir" ]] || return 1
  find "$target_dir" -type f -name "SKILL.md" -print -quit | grep -q .
}

global_target_dir_for() {
  local skill_name="$1"
  local source_type="$2"
  resolve_target_dir "$skill_name" "global" "$source_type"
}

adopt_existing_install() {
  local skill_name="$1"
  local mode="$2"
  local source_type="$3"
  local repo_url="$4"
  local target_dir="$5"

  write_source_metadata "$target_dir" "$skill_name" "$source_type" "$repo_url"
  write_install_metadata "$skill_name" "$mode" "$source_type" "$repo_url" "$target_dir"
}

adopt_existing_global_install_if_present() {
  local skill_name="$1"
  local mode="$2"
  local source_type="$3"
  local repo_url="$4"
  local global_target_dir

  [[ "$mode" == "global" ]] || return 1

  global_target_dir="$(global_target_dir_for "$skill_name" "$source_type")"
  if target_contains_skill_files "$global_target_dir"; then
    echo "Global skill $skill_name is already present at $global_target_dir. Adopting the existing installation."
    adopt_existing_install "$skill_name" "$mode" "$source_type" "$repo_url" "$global_target_dir"
    return 0
  fi

  return 1
}

note_existing_global_install_for_project_mode() {
  local skill_name="$1"
  local mode="$2"
  local source_type="$3"
  local global_target_dir

  [[ "$mode" == "project" ]] || return 0

  global_target_dir="$(global_target_dir_for "$skill_name" "$source_type")"
  if target_contains_skill_files "$global_target_dir"; then
    echo "Note: Global skill $skill_name is already present at $global_target_dir."
  fi
}

replace_directory() {
  local source_dir="$1"
  local target_dir="$2"

  rm -rf "$target_dir"
  mkdir -p "$(dirname "$target_dir")"
  cp -R "$source_dir" "$target_dir"
}

strip_agents_managed_block() {
  local source_file="$1"
  local output_file="$2"
  local start_marker="$3"
  local end_marker="$4"

  awk '
    $0 == start { skip=1; next }
    $0 == end { skip=0; next }
    skip != 1 { print }
  ' start="$start_marker" end="$end_marker" "$source_file" > "$output_file"
}

ensure_agents_file() {
  local agents_file="$1"
  local title="$2"

  mkdir -p "$(dirname "$agents_file")"
  if [[ ! -f "$agents_file" ]]; then
    cat >"$agents_file" <<EOF
- Always use real umlauts in externally visible text: \`ä, ö, ü, Ä, Ö, Ü, ß\`.

## $title
EOF
  fi
}

sync_agents_block() {
  local agents_file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local heading="$4"
  shift 4

  local temp_file
  local -a lines=("$@")

  ensure_agents_file "$agents_file" "$heading"
  temp_file="$(mktemp "${TMPDIR:-/tmp}/codex-agents.XXXXXX")"
  strip_agents_managed_block "$agents_file" "$temp_file" "$start_marker" "$end_marker"
  {
    cat "$temp_file"
    printf '\n%s\n' "$start_marker"
    printf '## %s\n\n' "$heading"
    if [[ ${#lines[@]} -eq 0 ]]; then
      printf -- '- none\n'
    else
      printf '%s\n' "${lines[@]}"
    fi
    printf '%s\n' "$end_marker"
  } > "$agents_file"
  rm -f "$temp_file"
}

sync_global_agents_file() {
  local metadata_file
  local -a skill_lines=()
  local -a selected_files=()
  local skill_count

  collect_selected_skill_metadata_files "global"
  selected_files=("${SELECTED_SKILL_METADATA_FILES[@]}")
  skill_count="${#selected_files[@]}"

  skill_lines+=("- Managed by this bootstrap as a compact global reference.")
  skill_lines+=("- Recorded global skills: \`$skill_count\`.")
  skill_lines+=("- Metadata directory: \`$PROJECT_STATE_DIR\`.")
  skill_lines+=("- Global skills root: \`$GLOBAL_SKILLS_DIR\`.")
  skill_lines+=("- Inspect the current inventory from \`$PROJECT_ROOT\` with \`./scripts/list_skills.sh\`.")

  sync_agents_block \
    "$GLOBAL_AGENTS_FILE" \
    "<!-- CODEX_GLOBAL_SKILLS_START -->" \
    "<!-- CODEX_GLOBAL_SKILLS_END -->" \
    "Managed Global Skills" \
    "${skill_lines[@]}"
}

sync_project_agents_file() {
  local metadata_file
  local -a skill_lines=()
  local -a selected_files=()

  collect_selected_skill_metadata_files "project"
  selected_files=("${SELECTED_SKILL_METADATA_FILES[@]}")

  for metadata_file in "${selected_files[@]}"; do
    load_skill_metadata "$metadata_file"
    skill_lines+=("- \`$NAME\`: Type \`$TYPE\` | Target \`$TARGET_DIR\` | Source \`$REPO_URL\`")
  done

  sync_agents_block \
    "$PROJECT_AGENTS_FILE" \
    "<!-- CODEX_PROJECT_SKILLS_START -->" \
    "<!-- CODEX_PROJECT_SKILLS_END -->" \
    "Managed Project Skills" \
    "${skill_lines[@]}"
}

collect_selected_skill_metadata_files() {
  local mode_filter="${1:-}"
  local metadata_file key canonical_file selected_file selected_index
  local -a files=()
  SELECTED_SKILL_METADATA_KEYS=()
  SELECTED_SKILL_METADATA_FILES=()
  STALE_SKILL_METADATA_FILES=()

  while IFS= read -r metadata_file; do
    files+=("$metadata_file")
  done < <(find "$PROJECT_STATE_DIR" -maxdepth 1 -type f -name '*.env' | LC_ALL=C sort)

  for metadata_file in "${files[@]}"; do
    load_skill_metadata "$metadata_file"
    [[ -n "$NAME" && -n "$MODE" ]] || continue
    if [[ -n "$mode_filter" && "$MODE" != "$mode_filter" ]]; then
      continue
    fi

    key="$MODE::$NAME"
    canonical_file="$(canonical_skill_metadata_path_for "$NAME" "$MODE")"
    if ! selected_index="$(find_selected_key_index "$key")"; then
      SELECTED_SKILL_METADATA_KEYS+=("$key")
      SELECTED_SKILL_METADATA_FILES+=("$metadata_file")
      continue
    fi

    selected_file="${SELECTED_SKILL_METADATA_FILES[$selected_index]}"

    if [[ "$metadata_file" == "$canonical_file" ]]; then
      STALE_SKILL_METADATA_FILES+=("$selected_file")
      SELECTED_SKILL_METADATA_FILES[$selected_index]="$metadata_file"
    else
      STALE_SKILL_METADATA_FILES+=("$metadata_file")
    fi
  done
}

install_repo_subdir() {
  local skill_name="$1"
  local mode="$2"
  local source_type="$3"
  local repo_url="$4"
  local sparse_path="$5"
  local source_subdir="$6"
  local target_dir
  target_dir="$(resolve_target_dir "$skill_name" "$mode" "$source_type")"

  if adopt_existing_global_install_if_present "$skill_name" "$mode" "$source_type" "$repo_url"; then
    return 0
  fi
  note_existing_global_install_for_project_mode "$skill_name" "$mode" "$source_type"

  copy_repo_subdir() {
    local repo_dir="$1"
    replace_directory "$repo_dir/$source_subdir" "$target_dir"
    write_source_metadata "$target_dir" "$skill_name" "$source_type" "$repo_url"
    write_install_metadata "$skill_name" "$mode" "$source_type" "$repo_url" "$target_dir"
  }

  with_temp_repo "$repo_url" "$sparse_path" copy_repo_subdir
}

with_temp_repo() {
  local repo_url="$1"
  local sparse_path="${2:-}"
  local callback="$3"
  local temp_dir repo_dir

  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/skill-install.XXXXXX")"
  repo_dir="$temp_dir/repo"

  if [[ -n "$sparse_path" ]]; then
    git clone --depth 1 --filter=blob:none --sparse "$repo_url" "$repo_dir" >/dev/null
    (
      cd "$repo_dir"
      git sparse-checkout set "$sparse_path" >/dev/null
    )
  else
    git clone --depth 1 "$repo_url" "$repo_dir" >/dev/null
  fi

  "$callback" "$repo_dir"
  rm -rf "$temp_dir"
}

resolve_target_dir() {
  local skill_name="$1"
  local mode="$2"
  local type="$3"

  if [[ "$mode" == "global" ]]; then
    if [[ "$type" == "collection" ]]; then
      printf '%s/%s' "$GLOBAL_COLLECTIONS_DIR" "$skill_name"
    else
      printf '%s/%s' "$GLOBAL_SKILLS_DIR" "$skill_name"
    fi
  else
    if [[ "$type" == "collection" ]]; then
      printf '%s/%s' "$PROJECT_CACHE_DIR" "$skill_name"
    else
      printf '%s/%s' "$PROJECT_SKILLS_DIR" "$skill_name"
    fi
  fi
}

install_frontend_design() {
  local mode="$1"
  local repo_url="https://github.com/anthropics/claude-code.git"
  local target_dir
  target_dir="$(resolve_target_dir "frontend-design" "$mode" "skill")"

  if adopt_existing_global_install_if_present "frontend-design" "$mode" "skill" "$repo_url"; then
    return 0
  fi
  note_existing_global_install_for_project_mode "frontend-design" "$mode" "skill"

  copy_repo() {
    local repo_dir="$1"
    replace_directory "$repo_dir/plugins/frontend-design/skills/frontend-design" "$target_dir"
    write_source_metadata "$target_dir" "frontend-design" "skill" "$repo_url"
    write_install_metadata "frontend-design" "$mode" "skill" "$repo_url" "$target_dir"
  }

  with_temp_repo "$repo_url" "plugins/frontend-design" copy_repo
}

install_humanizer() {
  local mode="$1"
  local repo_url="https://github.com/blader/humanizer.git"
  local target_dir
  target_dir="$(resolve_target_dir "humanizer" "$mode" "skill")"

  if adopt_existing_global_install_if_present "humanizer" "$mode" "skill" "$repo_url"; then
    return 0
  fi
  note_existing_global_install_for_project_mode "humanizer" "$mode" "skill"

  copy_repo() {
    local repo_dir="$1"
    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    cp "$repo_dir/SKILL.md" "$target_dir/SKILL.md"
    [[ -f "$repo_dir/README.md" ]] && cp "$repo_dir/README.md" "$target_dir/UPSTREAM_README.md"
    [[ -f "$repo_dir/LICENSE" ]] && cp "$repo_dir/LICENSE" "$target_dir/LICENSE"
    write_source_metadata "$target_dir" "humanizer" "skill" "$repo_url"
    write_install_metadata "humanizer" "$mode" "skill" "$repo_url" "$target_dir"
  }

  with_temp_repo "$repo_url" "" copy_repo
}

install_marketingskills() {
  local mode="$1"
  local repo_url="https://github.com/coreyhaines31/marketingskills.git"
  local target_dir
  target_dir="$(resolve_target_dir "marketingskills" "$mode" "collection")"

  if adopt_existing_global_install_if_present "marketingskills" "$mode" "collection" "$repo_url"; then
    return 0
  fi
  note_existing_global_install_for_project_mode "marketingskills" "$mode" "collection"

  copy_repo() {
    local repo_dir="$1"
    replace_directory "$repo_dir/skills" "$target_dir"
    write_source_metadata "$target_dir" "marketingskills" "collection" "$repo_url"
    write_install_metadata "marketingskills" "$mode" "collection" "$repo_url" "$target_dir"
  }

  with_temp_repo "$repo_url" "skills" copy_repo
}

install_financial_services() {
  local mode="$1"
  local repo_url="https://github.com/anthropics/financial-services.git"
  install_repo_subdir "financial-services" "$mode" "collection" "$repo_url" "plugins" "plugins"
}

install_ui_ux_pro_max() {
  local mode="$1"
  local repo_url="https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git"
  install_repo_subdir "ui-ux-pro-max" "$mode" "skill" "$repo_url" ".claude/skills/ui-ux-pro-max" ".claude/skills/ui-ux-pro-max"
}

install_drawio_diagrams_enhanced() {
  local mode="$1"
  local repo_url="https://github.com/jgtolentino/insightpulse-odoo.git"
  install_repo_subdir "drawio-diagrams-enhanced" "$mode" "skill" "$repo_url" "docs/claude-code-skills/community/drawio-diagrams-enhanced" "docs/claude-code-skills/community/drawio-diagrams-enhanced"
}

install_svg_precision() {
  local mode="$1"
  local repo_url="https://github.com/dkyazzentwatwa/chatgpt-skills.git"
  install_repo_subdir "svg-precision" "$mode" "skill" "$repo_url" "svg-precision-skill" "svg-precision-skill"
}

install_pptx() {
  local mode="$1"
  local repo_url="https://github.com/anthropics/skills.git"
  install_repo_subdir "pptx" "$mode" "skill" "$repo_url" "skills/pptx" "skills/pptx"
}

install_senior_architect() {
  local mode="$1"
  local repo_url="https://github.com/alirezarezvani/claude-skills.git"
  install_repo_subdir "senior-architect" "$mode" "skill" "$repo_url" "engineering-team/skills/senior-architect" "engineering-team/skills/senior-architect"
}

install_brand_voice() {
  local mode="$1"
  local repo_url="https://github.com/anthropics/knowledge-work-plugins.git"
  install_repo_subdir "brand-voice" "$mode" "collection" "$repo_url" "partner-built/brand-voice" "partner-built/brand-voice"
}

install_infographic_creation() {
  local mode="$1"
  local repo_url="https://github.com/antvis/Infographic.git"
  install_repo_subdir "infographic-creation" "$mode" "skill" "$repo_url" "skills/infographic-creator" "skills/infographic-creator"
}

install_jira_expert() {
  local mode="$1"
  local repo_url="https://github.com/alirezarezvani/claude-skills.git"
  install_repo_subdir "jira-expert" "$mode" "skill" "$repo_url" "project-management/skills/jira-expert" "project-management/skills/jira-expert"
}

install_confluence() {
  local mode="$1"
  local repo_url="https://github.com/alirezarezvani/claude-skills.git"
  install_repo_subdir "confluence" "$mode" "skill" "$repo_url" "project-management/skills/confluence-expert" "project-management/skills/confluence-expert"
}

install_skill_by_name() {
  local skill_name="$1"
  local mode="$2"

  case "$skill_name" in
    financial-services) install_financial_services "$mode" ;;
    marketingskills) install_marketingskills "$mode" ;;
    frontend-design) install_frontend_design "$mode" ;;
    humanizer) install_humanizer "$mode" ;;
    ui-ux-pro-max) install_ui_ux_pro_max "$mode" ;;
    drawio-diagrams-enhanced) install_drawio_diagrams_enhanced "$mode" ;;
    svg-precision) install_svg_precision "$mode" ;;
    pptx) install_pptx "$mode" ;;
    senior-architect) install_senior_architect "$mode" ;;
    brand-voice) install_brand_voice "$mode" ;;
    infographic-creation) install_infographic_creation "$mode" ;;
    jira-expert) install_jira_expert "$mode" ;;
    confluence) install_confluence "$mode" ;;
    *)
      echo "Error: Unsupported skill source: $skill_name" >&2
      exit 1
      ;;
  esac
}

count_skill_files() {
  local target_dir="$1"
  find "$target_dir" -type f -name "SKILL.md" | wc -l | tr -d ' '
}

path_is_managed_target() {
  local needle="$1"
  local target

  for target in "${MANAGED_SKILL_TARGETS[@]-}"; do
    if [[ "$target" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

discover_unmanaged_skills_in_root() {
  local root_dir="$1"
  local scope_label="$2"
  local type_label="$3"
  local child_dir name skill_count

  [[ -d "$root_dir" ]] || return 0

  while IFS= read -r child_dir; do
    [[ -d "$child_dir" ]] || continue
    name="$(basename "$child_dir")"
    if [[ "$name" == .* ]]; then
      continue
    fi
    if [[ "$root_dir" == "$GLOBAL_SKILLS_DIR" && "$name" == "_vendor" ]]; then
      continue
    fi
    if path_is_managed_target "$child_dir"; then
      continue
    fi
    if ! find "$child_dir" -type f -name "SKILL.md" -print -quit | grep -q .; then
      continue
    fi

    skill_count="$(count_skill_files "$child_dir")"
    UNMANAGED_SKILL_LINES+=("- $name | Scope: $scope_label | Type: $type_label | Status: present | Target: $child_dir | SKILL.md files: $skill_count")
  done < <(find "$root_dir" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort)
}

print_installations() {
  local file
  local found=0
  local status
  local -a selected_files=()
  local -a managed_targets=()

  collect_selected_skill_metadata_files
  selected_files=("${SELECTED_SKILL_METADATA_FILES[@]}")
  MANAGED_SKILL_TARGETS=()
  UNMANAGED_SKILL_LINES=()

  echo "Managed skill inventory:"
  for file in "${selected_files[@]}"; do
    found=1
    load_skill_metadata "$file"
    MANAGED_SKILL_TARGETS+=("$TARGET_DIR")
    if [[ -d "$TARGET_DIR" ]]; then
      status="present"
    else
      status="missing"
    fi
    echo "- $NAME | Mode: $MODE | Type: $TYPE | Status: $status | Source: $REPO_URL | Target: $TARGET_DIR | Updated: $UPDATED_AT"
    if [[ -d "$TARGET_DIR" ]]; then
      echo "  SKILL.md files: $(count_skill_files "$TARGET_DIR")"
    fi
  done

  if [[ "$found" -eq 0 ]]; then
    echo "- none"
  fi

  if [[ ${#STALE_SKILL_METADATA_FILES[@]} -gt 0 ]]; then
    echo
    echo "Ignored stale metadata files:"
    for file in "${STALE_SKILL_METADATA_FILES[@]}"; do
      echo "- $file"
    done
  fi

  discover_unmanaged_skills_in_root "$GLOBAL_SKILLS_DIR" "global" "skill"
  discover_unmanaged_skills_in_root "$GLOBAL_COLLECTIONS_DIR" "global" "collection"
  discover_unmanaged_skills_in_root "$PROJECT_SKILLS_DIR" "project" "skill"
  discover_unmanaged_skills_in_root "$PROJECT_CACHE_DIR" "project" "collection"

  if [[ ${#UNMANAGED_SKILL_LINES[@]} -gt 0 ]]; then
    echo
    echo "Filesystem-discovered unmanaged skills:"
    printf '%s\n' "${UNMANAGED_SKILL_LINES[@]}"
  fi
}

bootstrap_install_skills() {
  ensure_command git
  ensure_base_dirs

  local mode=""
  local -a requested=()
  local arg

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --mode)
        mode="$2"
        shift 2
        ;;
      global)
        if [[ -z "$mode" && ${#requested[@]} -eq 0 ]]; then
          mode="global"
          shift
        else
          requested+=("$1")
          shift
        fi
        ;;
      workspace|project)
        if [[ -z "$mode" && ${#requested[@]} -eq 0 ]]; then
          mode="project"
          shift
        else
          requested+=("$1")
          shift
        fi
        ;;
      -h|--help)
        usage_install
        return
        ;;
      *)
        requested+=("$1")
        shift
        ;;
    esac
  done

  [[ ${#requested[@]} -gt 0 ]] || {
    usage_install
    return 1
  }

  if [[ -z "$mode" ]]; then
    mode="$(prompt_mode)"
  fi
  [[ "$mode" == "global" || "$mode" == "project" || "$mode" == "workspace" ]] || {
    echo "Error: mode must be 'global' or 'project'." >&2
    return 1
  }
  if [[ "$mode" == "workspace" ]]; then
    mode="project"
  fi

  if [[ "${requested[0]}" == "all" ]]; then
    requested=()
    while IFS= read -r arg; do
      requested+=("$arg")
    done < <(list_supported_skills)
  fi

  for arg in "${requested[@]}"; do
    echo "Installing $arg in $mode mode..."
    install_skill_by_name "$arg" "$mode"
  done

  if [[ "$mode" == "global" ]]; then
    sync_global_agents_file
  else
    sync_project_agents_file
  fi

  echo
  print_installations
}

bootstrap_update_skills() {
  ensure_command git
  ensure_base_dirs

  local -a requested=()
  local file name_found
  local -a selected_files=()

  [[ "$#" -gt 0 ]] || {
    usage_update
    return 1
  }

  collect_selected_skill_metadata_files
  selected_files=("${SELECTED_SKILL_METADATA_FILES[@]}")

  if [[ "$1" == "all" ]]; then
    for file in "${selected_files[@]}"; do
      load_skill_metadata "$file"
      echo "Updating $NAME in $MODE mode..."
      install_skill_by_name "$NAME" "$MODE"
      if [[ "$MODE" == "global" ]]; then
        sync_global_agents_file
      else
        sync_project_agents_file
      fi
    done
  else
    requested=("$@")
    for name_found in "${requested[@]}"; do
      local matched=0
      for file in "${selected_files[@]}"; do
        load_skill_metadata "$file"
        if [[ "$NAME" == "$name_found" ]]; then
          matched=1
          echo "Updating $NAME in $MODE mode..."
          install_skill_by_name "$NAME" "$MODE"
          if [[ "$MODE" == "global" ]]; then
            sync_global_agents_file
          else
            sync_project_agents_file
          fi
        fi
      done
      if [[ "$matched" -eq 0 ]]; then
        echo "No managed installation found for $name_found." >&2
      fi
    done
  fi

  echo
  print_installations
}

bootstrap_list_skills() {
  ensure_base_dirs
  print_installations
}
