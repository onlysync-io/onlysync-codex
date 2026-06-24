#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$BOOTSTRAP_ROOT/.." && pwd)"
PROJECT_STATE_DIR="$BOOTSTRAP_ROOT/tool-installs"
PROJECT_TOOLS_DIR="$BOOTSTRAP_ROOT/tools"
PROJECT_BIN_DIR="$PROJECT_TOOLS_DIR/bin"
GLOBAL_TOOL_ROOT="$HOME/.codex/workbench"
GLOBAL_PYTHON_VENV="$GLOBAL_TOOL_ROOT/python"
GLOBAL_BIN_DIR="$HOME/.local/bin"
GLOBAL_AGENTS_FILE="$HOME/.codex/AGENTS.md"
PROJECT_AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"

SUPPORTED_TOOL_BUNDLES=(
  "core"
  "documents"
  "pdf-images"
  "diagrams"
  "browser-automation"
  "composio-cli"
)

usage_install_tools() {
  cat <<'EOF'
Usage:
  ./scripts/install_tools.sh all
  ./scripts/install_tools.sh core documents composio-cli
  ./scripts/install_tools.sh --mode global all
  ./scripts/install_tools.sh --mode project documents browser-automation
EOF
}

usage_update_tools() {
  cat <<'EOF'
Usage:
  ./scripts/update_tools.sh all
  ./scripts/update_tools.sh core documents composio-cli
EOF
}

is_apple_silicon() {
  [[ "$(uname -m)" == "arm64" ]]
}

is_rosetta_shell() {
  [[ "$(sysctl -n sysctl.proc_translated 2>/dev/null || printf 0)" == "1" ]]
}

resolve_homebrew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    printf '%s\n' "/opt/homebrew/bin/brew"
  elif [[ -x /usr/local/bin/brew ]]; then
    printf '%s\n' "/usr/local/bin/brew"
  elif command -v brew >/dev/null 2>&1; then
    command -v brew
  else
    return 1
  fi
}

run_brew() {
  local brew_bin
  brew_bin="$(resolve_homebrew)"
  if is_apple_silicon && is_rosetta_shell && command -v arch >/dev/null 2>&1; then
    arch -arm64 "$brew_bin" "$@"
  else
    "$brew_bin" "$@"
  fi
}

run_npm_global() {
  if is_apple_silicon && command -v arch >/dev/null 2>&1; then
    arch -arm64 npm "$@"
  else
    npm "$@"
  fi
}

run_npx_global() {
  if is_apple_silicon && command -v arch >/dev/null 2>&1; then
    arch -arm64 npx "$@"
  else
    npx "$@"
  fi
}

ensure_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: Required command is missing: $command_name" >&2
    exit 1
  fi
}

ensure_base_dirs() {
  mkdir -p "$PROJECT_STATE_DIR" "$PROJECT_TOOLS_DIR" "$PROJECT_BIN_DIR" "$GLOBAL_TOOL_ROOT" "$GLOBAL_BIN_DIR"
}

canonical_tool_metadata_path_for() {
  local bundle="$1"
  local mode="$2"
  printf '%s/%s--%s.env' "$PROJECT_STATE_DIR" "$mode" "$bundle"
}

decode_metadata_value() {
  local raw_value="$1"

  if [[ "$raw_value" == \'*\' && "$raw_value" == *\' ]]; then
    printf '%s' "${raw_value:1:${#raw_value}-2}"
  else
    printf '%s' "$raw_value" | sed -e 's/\\ / /g' -e 's/\\,/,/g' -e 's/\\|/|/g' -e 's/\\\\/\\/g'
  fi
}

load_tool_metadata() {
  local metadata_file="$1"
  local key raw_value decoded_value

  unset NAME MODE TYPE SCOPE_SUPPORT TARGET_DIR COMMANDS PACKAGES NOTES UPDATED_AT
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

  for entry in "${SELECTED_TOOL_METADATA_KEYS[@]-}"; do
    if [[ "$entry" == "$needle" ]]; then
      printf '%s' "$index"
      return 0
    fi
    index=$((index + 1))
  done
  return 1
}

ensure_homebrew() {
  if ! command -v brew >/dev/null 2>&1 && ! resolve_homebrew >/dev/null 2>&1; then
    echo "Homebrew was not found. Starting installation..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$("$(resolve_homebrew)" shellenv)"
}

list_supported_tool_bundles() {
  printf '%s\n' "${SUPPORTED_TOOL_BUNDLES[@]}"
}

prompt_mode_tools() {
  local input
  while true; do
    read -r -p "Choose tool mode [global/workspace]: " input
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

supports_project_mode() {
  local bundle="$1"
  case "$bundle" in
    documents|browser-automation) return 0 ;;
    *) return 1 ;;
  esac
}

tool_metadata_path_for() {
  local bundle="$1"
  local mode="$2"
  canonical_tool_metadata_path_for "$bundle" "$mode"
}

write_tool_metadata() {
  local bundle="$1"
  local mode="$2"
  local scope_support="$3"
  local target_dir="$4"
  local commands="$5"
  local packages="$6"
  local notes="$7"
  local updated_at

  updated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  {
    printf 'NAME=%q\n' "$bundle"
    printf 'MODE=%q\n' "$mode"
    printf 'TYPE=%q\n' "bundle"
    printf 'SCOPE_SUPPORT=%q\n' "$scope_support"
    printf 'TARGET_DIR=%q\n' "$target_dir"
    printf 'COMMANDS=%q\n' "$commands"
    printf 'PACKAGES=%q\n' "$packages"
    printf 'NOTES=%q\n' "$notes"
    printf 'UPDATED_AT=%q\n' "$updated_at"
  } > "$(tool_metadata_path_for "$bundle" "$mode")"
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
  local -a bundle_lines=()
  local -a selected_files=()
  local bundle_count

  collect_selected_tool_metadata_files "global"
  selected_files=("${SELECTED_TOOL_METADATA_FILES[@]}")
  bundle_count="${#selected_files[@]}"

  bundle_lines+=("- Managed by this bootstrap as a compact global reference.")
  bundle_lines+=("- Recorded global tool bundles: \`$bundle_count\`.")
  bundle_lines+=("- Metadata directory: \`$PROJECT_STATE_DIR\`.")
  bundle_lines+=("- Global workbench root: \`$GLOBAL_TOOL_ROOT\`.")
  bundle_lines+=("- Inspect the current inventory from \`$PROJECT_ROOT\` with \`./scripts/list_tools.sh\`.")

  sync_agents_block \
    "$GLOBAL_AGENTS_FILE" \
    "<!-- CODEX_GLOBAL_TOOL_BUNDLES_START -->" \
    "<!-- CODEX_GLOBAL_TOOL_BUNDLES_END -->" \
    "Managed Global Tool Bundles" \
    "${bundle_lines[@]}"
}

sync_project_agents_file() {
  local metadata_file
  local -a bundle_lines=()
  local -a selected_files=()

  collect_selected_tool_metadata_files "project"
  selected_files=("${SELECTED_TOOL_METADATA_FILES[@]}")

  for metadata_file in "${selected_files[@]}"; do
    load_tool_metadata "$metadata_file"
    bundle_lines+=("- \`$NAME\`: Target \`$TARGET_DIR\` | Commands \`$COMMANDS\` | Packages \`$PACKAGES\`")
    if [[ -n "$NOTES" ]]; then
      bundle_lines+=("  Note: $NOTES")
    fi
  done

  sync_agents_block \
    "$PROJECT_AGENTS_FILE" \
    "<!-- CODEX_PROJECT_TOOL_BUNDLES_START -->" \
    "<!-- CODEX_PROJECT_TOOL_BUNDLES_END -->" \
    "Managed Project Tool Bundles" \
    "${bundle_lines[@]}"
}

collect_selected_tool_metadata_files() {
  local mode_filter="${1:-}"
  local metadata_file key canonical_file selected_file selected_index
  local -a files=()
  SELECTED_TOOL_METADATA_KEYS=()
  SELECTED_TOOL_METADATA_FILES=()
  STALE_TOOL_METADATA_FILES=()

  while IFS= read -r metadata_file; do
    files+=("$metadata_file")
  done < <(find "$PROJECT_STATE_DIR" -maxdepth 1 -type f -name '*.env' | LC_ALL=C sort)

  for metadata_file in "${files[@]}"; do
    load_tool_metadata "$metadata_file"
    [[ -n "$NAME" && -n "$MODE" ]] || continue
    if [[ -n "$mode_filter" && "$MODE" != "$mode_filter" ]]; then
      continue
    fi

    key="$MODE::$NAME"
    canonical_file="$(canonical_tool_metadata_path_for "$NAME" "$MODE")"
    if ! selected_index="$(find_selected_key_index "$key")"; then
      SELECTED_TOOL_METADATA_KEYS+=("$key")
      SELECTED_TOOL_METADATA_FILES+=("$metadata_file")
      continue
    fi

    selected_file="${SELECTED_TOOL_METADATA_FILES[$selected_index]}"

    if [[ "$metadata_file" == "$canonical_file" ]]; then
      STALE_TOOL_METADATA_FILES+=("$selected_file")
      SELECTED_TOOL_METADATA_FILES[$selected_index]="$metadata_file"
    else
      STALE_TOOL_METADATA_FILES+=("$metadata_file")
    fi
  done
}

ensure_python_wrapper() {
  local python_bin="$1"
  local wrapper_dir="$2"

  mkdir -p "$wrapper_dir"
  cat >"$wrapper_dir/codex-python" <<EOF
#!/usr/bin/env bash
set -euo pipefail

"$python_bin" "\$@"
EOF
  cat >"$wrapper_dir/codex-markitdown" <<EOF
#!/usr/bin/env bash
set -euo pipefail

"$python_bin" -m markitdown "\$@"
EOF
  chmod +x "$wrapper_dir/codex-python" "$wrapper_dir/codex-markitdown"
}

ensure_composio_wrapper() {
  mkdir -p "$GLOBAL_BIN_DIR"
  cat >"$GLOBAL_BIN_DIR/composio" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

COMPOSIO_INSTALL_DIR="${COMPOSIO_INSTALL_DIR:-$HOME/.composio}"
"$COMPOSIO_INSTALL_DIR/composio" "$@"
EOF
  chmod +x "$GLOBAL_BIN_DIR/composio"
}

install_global_python_documents() {
  local python_bin

  if command -v python3.13 >/dev/null 2>&1; then
    python_bin="$(command -v python3.13)"
  else
    python_bin="$(command -v python3)"
  fi

  "$python_bin" -m venv "$GLOBAL_PYTHON_VENV"
  "$GLOBAL_PYTHON_VENV/bin/python" -m pip install --upgrade pip
  "$GLOBAL_PYTHON_VENV/bin/python" -m pip install --upgrade openpyxl python-docx python-pptx markitdown pypdf pymupdf
  ensure_python_wrapper "$GLOBAL_PYTHON_VENV/bin/python" "$GLOBAL_BIN_DIR"
}

install_project_python_documents() {
  local runtime_root="$PROJECT_TOOLS_DIR/documents"
  local python_venv="$runtime_root/python"
  local python_bin

  mkdir -p "$runtime_root"
  if command -v python3.13 >/dev/null 2>&1; then
    python_bin="$(command -v python3.13)"
  else
    python_bin="$(command -v python3)"
  fi

  "$python_bin" -m venv "$python_venv"
  "$python_venv/bin/python" -m pip install --upgrade pip
  "$python_venv/bin/python" -m pip install --upgrade openpyxl python-docx python-pptx markitdown pypdf pymupdf
  ensure_python_wrapper "$python_venv/bin/python" "$PROJECT_BIN_DIR"
}

install_global_node_documents() {
  npm install -g mammoth docx xlsx pptxgenjs pdf-parse >/dev/null
}

install_project_node_documents() {
  local runtime_root="$PROJECT_TOOLS_DIR/documents"

  mkdir -p "$runtime_root"
  if [[ ! -f "$runtime_root/package.json" ]]; then
    npm init -y --prefix "$runtime_root" >/dev/null
  fi
  npm install --prefix "$runtime_root" mammoth docx xlsx pptxgenjs pdf-parse >/dev/null
}

install_project_browser_runtime() {
  local runtime_root="$PROJECT_TOOLS_DIR/browser-automation"

  mkdir -p "$runtime_root"
  if [[ ! -f "$runtime_root/package.json" ]]; then
    npm init -y --prefix "$runtime_root" >/dev/null
  fi
  npm install --prefix "$runtime_root" playwright >/dev/null
  npx --prefix "$runtime_root" playwright install >/dev/null

  cat >"$PROJECT_BIN_DIR/codex-playwright" <<EOF
#!/usr/bin/env bash
set -euo pipefail

npx --prefix "$runtime_root" playwright "\$@"
EOF
  chmod +x "$PROJECT_BIN_DIR/codex-playwright"
}

install_core_bundle() {
  local mode="$1"

  if [[ "$mode" == "project" ]]; then
    echo "Bundle 'core' supports global mode only." >&2
    return 1
  fi

  ensure_command git
  ensure_homebrew
  run_brew update
  run_brew install python python@3.13 node git curl pipx ripgrep
  pipx ensurepath >/dev/null 2>&1 || true
  write_tool_metadata "core" "$mode" "global_only" "/opt/homebrew|/usr/local|$GLOBAL_BIN_DIR" "python3,node,npm,git,curl,pipx,rg" "brew:python,python@3.13,node,git,curl,pipx,ripgrep" "Core system tools are installed globally only."
}

install_documents_bundle() {
  local mode="$1"

  ensure_command npm
  if [[ "$mode" == "global" ]]; then
    ensure_homebrew
    run_brew install pandoc pymupdf
    install_global_python_documents
    install_global_node_documents
    write_tool_metadata "documents" "$mode" "global_or_project" "$GLOBAL_PYTHON_VENV|/opt/homebrew|/usr/local" "codex-python,codex-markitdown,pandoc,pymupdf" "brew:pandoc,pymupdf|python:openpyxl,python-docx,python-pptx,markitdown,pypdf,pymupdf|npm:mammoth,docx,xlsx,pptxgenjs,pdf-parse" "Global document workbench for Office generation, extraction, and PDF parsing, including PyMuPDF and Node document parsers and generators."
    sync_global_agents_file
  else
    install_project_python_documents
    install_project_node_documents
    write_tool_metadata "documents" "$mode" "global_or_project" "$PROJECT_TOOLS_DIR/documents" "$PROJECT_BIN_DIR/codex-python,$PROJECT_BIN_DIR/codex-markitdown" "python:openpyxl,python-docx,python-pptx,markitdown,pypdf,pymupdf|npm:mammoth,docx,xlsx,pptxgenjs,pdf-parse" "Workspace mode creates a local document runtime with Python and Node packages. Pandoc and the Homebrew PyMuPDF formula remain globally preferred native tools."
  fi
}

install_pdf_images_bundle() {
  local mode="$1"

  if [[ "$mode" == "project" ]]; then
    echo "Bundle 'pdf-images' supports global mode only." >&2
    return 1
  fi

  ensure_homebrew
  run_brew install ffmpeg imagemagick ghostscript
  write_tool_metadata "pdf-images" "$mode" "global_only" "/opt/homebrew|/usr/local" "ffmpeg,magick,gs" "brew:ffmpeg,imagemagick,ghostscript" "Native tools for rendering, conversion, and technical PDF/image work."
}

install_diagrams_bundle() {
  local mode="$1"

  if [[ "$mode" == "project" ]]; then
    echo "Bundle 'diagrams' supports global mode only." >&2
    return 1
  fi

  ensure_homebrew
  run_brew install drawio
  write_tool_metadata "diagrams" "$mode" "global_only" "/opt/homebrew|/usr/local" "drawio" "brew:drawio" "Draw.io remains a globally installed native diagramming tool."
}

install_browser_automation_bundle() {
  local mode="$1"

  ensure_command npm
  if [[ "$mode" == "global" ]]; then
    run_npm_global install -g pnpm playwright
    run_npx_global -y playwright install
    write_tool_metadata "browser-automation" "$mode" "global_or_project" "$GLOBAL_BIN_DIR" "pnpm,playwright" "npm:pnpm,playwright" "Global browser automation via Node tooling."
    sync_global_agents_file
  else
    install_project_browser_runtime
    write_tool_metadata "browser-automation" "$mode" "global_or_project" "$PROJECT_TOOLS_DIR/browser-automation" "$PROJECT_BIN_DIR/codex-playwright" "npm:playwright" "Workspace mode creates a local Playwright runtime directory. pnpm remains globally preferred."
  fi
}

install_composio_cli_bundle() {
  local mode="$1"

  if [[ "$mode" == "project" ]]; then
    echo "Bundle 'composio-cli' supports global mode only." >&2
    return 1
  fi

  ensure_command curl
  ensure_command unzip
  curl -fsSL https://composio.dev/install | bash
  ensure_composio_wrapper
  write_tool_metadata "composio-cli" "$mode" "global_only" "$HOME/.composio|$GLOBAL_BIN_DIR" "composio" "script:https://composio.dev/install" "Composio CLI is installed via the official installer into ~/.composio, and the bootstrap adds a stable wrapper in ~/.local/bin."
}

install_tool_bundle_by_name() {
  local bundle="$1"
  local mode="$2"

  case "$bundle" in
    core) install_core_bundle "$mode" ;;
    documents) install_documents_bundle "$mode" ;;
    pdf-images) install_pdf_images_bundle "$mode" ;;
    diagrams) install_diagrams_bundle "$mode" ;;
    browser-automation) install_browser_automation_bundle "$mode" ;;
    composio-cli) install_composio_cli_bundle "$mode" ;;
    *)
      echo "Error: Unsupported tool bundle: $bundle" >&2
      exit 1
      ;;
  esac

  if [[ "$mode" == "global" ]]; then
    sync_global_agents_file
  else
    sync_project_agents_file
  fi
}

print_tool_installations() {
  local file found=0
  local display_name

  local -a selected_files=()

  collect_selected_tool_metadata_files
  selected_files=("${SELECTED_TOOL_METADATA_FILES[@]}")

  echo "Managed tool installations:"
  for file in "${selected_files[@]}"; do
    found=1
    load_tool_metadata "$file"
    display_name="$NAME ($MODE)"
    echo "- $display_name | Scope: $SCOPE_SUPPORT | Target: $TARGET_DIR | Commands: $COMMANDS | Updated: $UPDATED_AT"
    echo "  Packages: $PACKAGES"
    echo "  Note: $NOTES"
  done

  if [[ "$found" -eq 0 ]]; then
    echo "- none"
  fi

  if [[ ${#STALE_TOOL_METADATA_FILES[@]} -gt 0 ]]; then
    echo
    echo "Ignored stale metadata files:"
    for file in "${STALE_TOOL_METADATA_FILES[@]}"; do
      echo "- $file"
    done
  fi
}

bootstrap_install_tools() {
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
      -h|--help)
        usage_install_tools
        return
        ;;
      *)
        requested+=("$1")
        shift
        ;;
    esac
  done

  [[ ${#requested[@]} -gt 0 ]] || {
    usage_install_tools
    return 1
  }

  if [[ -z "$mode" ]]; then
    mode="$(prompt_mode_tools)"
  fi
  [[ "$mode" == "global" || "$mode" == "project" ]] || {
    echo "Error: mode must be 'global' or 'project'." >&2
    return 1
  }

  if [[ "${requested[0]}" == "all" ]]; then
    requested=()
    while IFS= read -r arg; do
      requested+=("$arg")
    done < <(list_supported_tool_bundles)
  fi

  for arg in "${requested[@]}"; do
    echo "Installing tool bundle $arg in $mode mode..."
    install_tool_bundle_by_name "$arg" "$mode"
  done

  echo
  print_tool_installations
}

bootstrap_update_tools() {
  ensure_base_dirs

  local -a requested=()
  local file name_found
  local -a selected_files=()

  [[ "$#" -gt 0 ]] || {
    usage_update_tools
    return 1
  }

  collect_selected_tool_metadata_files
  selected_files=("${SELECTED_TOOL_METADATA_FILES[@]}")

  if [[ "$1" == "all" ]]; then
    for file in "${selected_files[@]}"; do
      load_tool_metadata "$file"
      echo "Updating $NAME in $MODE mode..."
      install_tool_bundle_by_name "$NAME" "$MODE"
    done
  else
    requested=("$@")
    for name_found in "${requested[@]}"; do
      local matched=0
      for file in "${selected_files[@]}"; do
        load_tool_metadata "$file"
        if [[ "$NAME" == "$name_found" ]]; then
          matched=1
          echo "Updating $NAME in $MODE mode..."
          install_tool_bundle_by_name "$NAME" "$MODE"
        fi
      done
      if [[ "$matched" -eq 0 ]]; then
        echo "No managed installation found for $name_found." >&2
      fi
    done
  fi

  echo
  print_tool_installations
}

bootstrap_list_tools() {
  ensure_base_dirs
  print_tool_installations
}
