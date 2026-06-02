#!/usr/bin/env bash
set -euo pipefail

CODEX_PYTHON_TOOLS_VENV="$HOME/.codex/venvs/python-tools"

echo "Setting up Python 3, Node.js/npm, pnpm, FFmpeg, Remotion tooling, Composio, Meta Ads MCP/CLI helpers, macOS MCP servers, and Codex skills on macOS..."

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

echo "Updating Homebrew..."
brew update

echo "Installing Python 3, Python 3.13, Node.js/npm, FFmpeg, ImageMagick, Ghostscript, curl, git, and pipx..."
brew install python python@3.13 node ffmpeg imagemagick ghostscript curl git pipx

echo "Installing Noto Sans font..."
brew install --cask font-noto-sans

install_chatgpt_desktop() {
  local macos_major
  macos_major="$(sw_vers -productVersion | cut -d. -f1)"

  if [[ "$(uname -m)" == "arm64" && "$macos_major" -ge 14 ]]; then
    if brew list --cask chatgpt >/dev/null 2>&1; then
      echo "ChatGPT desktop app already installed through Homebrew."
    elif [[ -d "/Applications/ChatGPT.app" ]]; then
      echo "Skipping ChatGPT desktop app: /Applications/ChatGPT.app already exists."
      echo "To reinstall it through Homebrew, run: brew install --cask --force chatgpt"
    else
      echo "Installing ChatGPT desktop app..."
      brew install --cask chatgpt
    fi
  else
    echo "Skipping ChatGPT desktop app: it requires macOS 14+ on Apple Silicon."
  fi
}

echo "Installing Codex CLI..."
brew install --cask codex
npm install -g pnpm
install_chatgpt_desktop

configure_memory_mcp() {
  local codex_dir="$HOME/.codex"
  local codex_config="$codex_dir/config.toml"

  mkdir -p "$codex_dir"
  touch "$codex_config"

  if ! grep -q '^\[mcp_servers\.memory\]' "$codex_config"; then
    cat >> "$codex_config" <<'EOF'

[mcp_servers.memory]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-memory"]
enabled = true
EOF
  fi
}

configure_markitdown_mcp() {
  local codex_dir="$HOME/.codex"
  local codex_config="$codex_dir/config.toml"
  local command="$CODEX_PYTHON_TOOLS_VENV/bin/markitdown-mcp"

  mkdir -p "$codex_dir"
  touch "$codex_config"

  if grep -q '^\[mcp_servers\.markitdown\]' "$codex_config"; then
    local tmp_config
    tmp_config="$(mktemp "${TMPDIR:-/tmp}/codex-config.XXXXXX.toml")"

    awk -v command="$command" '
      BEGIN {
        in_section = 0
        wrote_command = 0
      }
      /^\[mcp_servers\.markitdown\]$/ {
        in_section = 1
        wrote_command = 0
        print
        next
      }
      /^\[.*\]$/ {
        if (in_section && !wrote_command) {
          print "command = \"" command "\""
        }
        in_section = 0
      }
      in_section && /^command = / {
        print "command = \"" command "\""
        wrote_command = 1
        next
      }
      {
        print
      }
      END {
        if (in_section && !wrote_command) {
          print "command = \"" command "\""
        }
      }
    ' "$codex_config" > "$tmp_config"
    mv "$tmp_config" "$codex_config"
  else
    cat >> "$codex_config" <<EOF

[mcp_servers.markitdown]
command = "$command"
enabled = true
EOF
  fi
}

configure_meta_ads_mcp() {
  local codex_dir="$HOME/.codex"
  local codex_config="$codex_dir/config.toml"
  local url="https://mcp.facebook.com/ads"
  local tmp_config

  mkdir -p "$codex_dir"
  touch "$codex_config"

  tmp_config="$(mktemp "${TMPDIR:-/tmp}/codex-config.XXXXXX.toml")"

  awk -v url="$url" '
    BEGIN {
      in_section = 0
      found = 0
    }
    /^\[mcp_servers\.meta_ads\]$/ {
      print "[mcp_servers.meta_ads]"
      print "url = \"" url "\""
      found = 1
      in_section = 1
      next
    }
    in_section && /^\[.*\]$/ {
      in_section = 0
    }
    in_section {
      next
    }
    {
      print
    }
    END {
      if (!found) {
        print ""
        print "[mcp_servers.meta_ads]"
        print "url = \"" url "\""
      }
    }
  ' "$codex_config" > "$tmp_config"

  mv "$tmp_config" "$codex_config"
}

install_python_packages() {
  mkdir -p "$(dirname "$CODEX_PYTHON_TOOLS_VENV")"
  python3 -m venv "$CODEX_PYTHON_TOOLS_VENV"
  "$CODEX_PYTHON_TOOLS_VENV/bin/python" -m pip install --upgrade pip
  "$CODEX_PYTHON_TOOLS_VENV/bin/python" -m pip install --upgrade holidays pillow rembg markitdown-mcp
}

install_meta_ads_cli() {
  local meta_python=""

  echo "Installing Meta Ads CLI..."
  if command -v python3.13 >/dev/null 2>&1; then
    meta_python="$(command -v python3.13)"
  elif [[ -x /opt/homebrew/bin/python3.13 ]]; then
    meta_python="/opt/homebrew/bin/python3.13"
  elif [[ -x /usr/local/bin/python3.13 ]]; then
    meta_python="/usr/local/bin/python3.13"
  fi

  if [[ -z "$meta_python" ]]; then
    echo "Meta Ads CLI was not installed because Python 3.13 was not found."
    echo "The official meta-ads package requires Python 3.12+ and currently ships wheels for CPython 3.12/3.13."
    echo "The Meta Ads MCP endpoint was still configured in ~/.codex/config.toml."
    return
  fi

  if "$meta_python" -m pip index versions meta-ads >/dev/null 2>&1; then
    if pipx install --force --python "$meta_python" meta-ads; then
      echo "Meta Ads CLI installed."
    else
      echo "Meta Ads CLI installation failed."
      echo "The official meta-ads package currently requires a compatible Python and wheel for your platform."
      echo "The Meta Ads MCP endpoint was still configured in ~/.codex/config.toml."
    fi
  else
    echo "Meta Ads CLI was not installed because no compatible meta-ads distribution was found for $meta_python."
    echo "The setup date for this check is June 2, 2026."
    echo "The Meta Ads MCP endpoint was still configured in ~/.codex/config.toml."
  fi
}

install_apple_mail_mcp() {
  local target="$HOME/.codex/mcp/apple-mail-mcp"

  mkdir -p "$target"
  python3 -m venv "$target/venv"
  "$target/venv/bin/python" -m pip install --upgrade pip
  "$target/venv/bin/python" -m pip install --upgrade mcp-apple-mail
}

configure_apple_mail_mcp() {
  local codex_dir="$HOME/.codex"
  local codex_config="$codex_dir/config.toml"
  local command="$HOME/.codex/mcp/apple-mail-mcp/venv/bin/mcp-apple-mail"

  mkdir -p "$codex_dir"
  touch "$codex_config"

  if ! grep -q '^\[mcp_servers\.apple_mail\]' "$codex_config"; then
    cat >> "$codex_config" <<EOF

[mcp_servers.apple_mail]
command = "$command"
enabled = true
EOF
  fi
}

install_apple_music_mcp() {
  local target="$HOME/.codex/mcp/applemusic-mcp"

  mkdir -p "$(dirname "$target")"
  if [[ -d "$target/.git" ]]; then
    git -C "$target" pull --ff-only
  else
    git clone https://github.com/epheterson/applemusic-mcp.git "$target"
  fi

  python3 -m venv "$target/venv"
  "$target/venv/bin/python" -m pip install --upgrade pip
  "$target/venv/bin/python" -m pip install --upgrade -e "$target"
}

configure_apple_music_mcp() {
  local codex_dir="$HOME/.codex"
  local codex_config="$codex_dir/config.toml"
  local command="$HOME/.codex/mcp/applemusic-mcp/venv/bin/python"

  mkdir -p "$codex_dir"
  touch "$codex_config"

  if ! grep -q '^\[mcp_servers\.apple_music\]' "$codex_config"; then
    cat >> "$codex_config" <<EOF

[mcp_servers.apple_music]
command = "$command"
args = ["-m", "applemusic_mcp"]
enabled = true
EOF
  fi
}

install_composio_fresh() {
  local composio_dir="$HOME/.composio"
  local composio_installer

  mkdir -p "$composio_dir"
  rm -f \
    "$composio_dir/composio" \
    "$composio_dir/composio.exe" \
    "$composio_dir/release-tag.txt" \
    "$composio_dir/update-check.json"

  composio_installer="$(mktemp "${TMPDIR:-/tmp}/composio-install.XXXXXX.sh")"
  curl -fsSL -o "$composio_installer" https://composio.dev/install
  bash "$composio_installer"
  rm -f "$composio_installer"

  verify_composio_version_marker
}

verify_composio_version_marker() {
  local composio_dir="$HOME/.composio"
  local composio_bin="$composio_dir/composio"
  local release_tag_path="$composio_dir/release-tag.txt"
  local update_check_path="$composio_dir/update-check.json"
  local installed_version
  local latest_version
  local release_tag

  if [[ ! -x "$composio_bin" || ! -f "$release_tag_path" ]]; then
    return
  fi

  release_tag="$(cat "$release_tag_path")"
  latest_version="${release_tag##*@}"
  installed_version="$("$composio_bin" --version 2>/dev/null | awk 'NF { value=$0 } END { print value }')"

  if [[ -n "$latest_version" && -n "$installed_version" && "$installed_version" != "$latest_version" ]]; then
    echo "Warning: Composio installer fetched $latest_version, but the binary reports $installed_version."
    echo "Removing Composio version markers so future upgrades do not treat the stale binary as current."
    rm -f "$release_tag_path" "$update_check_path"
  fi
}

install_apple_calendar_bridge() {
  local target="$HOME/.codex/mcp/apple-mcp-api-bridge"

  if ! command -v swift >/dev/null 2>&1; then
    echo "Skipping Apple Calendar MCP: Swift toolchain not found."
    echo "Install Xcode Command Line Tools with: xcode-select --install"
    return 1
  fi

  mkdir -p "$(dirname "$target")"
  if [[ -d "$target/.git" ]]; then
    git -C "$target" pull --ff-only
  elif [[ -e "$target" ]]; then
    echo "Apple Calendar bridge path exists but is not a git checkout: $target"
    return 1
  else
    git clone https://github.com/shadowfax92/apple-mcp-api-bridge.git "$target"
  fi

  swift build -c release --package-path "$target"
}

install_apple_calendar_mcp() {
  local target="$HOME/.codex/mcp/apple-calendar-mcp"
  local wrapper="$target/run-apple-calendar-mcp.sh"

  mkdir -p "$(dirname "$target")"
  if [[ -d "$target/.git" ]]; then
    git -C "$target" pull --ff-only
  elif [[ -e "$target" ]]; then
    echo "Apple Calendar MCP path exists but is not a git checkout: $target"
    return 1
  else
    git clone https://github.com/shadowfax92/apple-calendar-mcp.git "$target"
  fi

  npm install --prefix "$target"
  npm run --prefix "$target" build

  cat > "$wrapper" <<EOF
#!/usr/bin/env bash
set -euo pipefail

bridge="$HOME/.codex/mcp/apple-mcp-api-bridge/.build/release/MacAPIBridge"
server="$HOME/.codex/mcp/apple-calendar-mcp/dist/index.js"

if ! /usr/bin/nc -z 127.0.0.1 8080 >/dev/null 2>&1; then
  "\$bridge" >> "\${TMPDIR:-/tmp}/apple-calendar-bridge.log" 2>&1 &
  sleep 2
fi

exec node "\$server"
EOF
  chmod +x "$wrapper"
}

configure_apple_calendar_mcp() {
  local codex_dir="$HOME/.codex"
  local codex_config="$codex_dir/config.toml"
  local command="$HOME/.codex/mcp/apple-calendar-mcp/run-apple-calendar-mcp.sh"

  mkdir -p "$codex_dir"
  touch "$codex_config"

  if ! grep -q '^\[mcp_servers\.apple_calendar\]' "$codex_config"; then
    cat >> "$codex_config" <<EOF

[mcp_servers.apple_calendar]
command = "$command"
enabled = true
EOF
  fi
}

echo "Installing Memory MCP server..."
npm install -g @modelcontextprotocol/server-memory
configure_memory_mcp
configure_meta_ads_mcp
install_meta_ads_cli

echo "Installing Python packages..."
install_python_packages
configure_markitdown_mcp

echo "Installing macOS-only MCP servers..."
install_apple_mail_mcp
configure_apple_mail_mcp
install_apple_music_mcp
configure_apple_music_mcp
if install_apple_calendar_bridge && install_apple_calendar_mcp; then
  configure_apple_calendar_mcp
else
  echo "Apple Calendar MCP was not configured. Install the Swift toolchain and rerun setup."
fi

echo "Installing Composio..."
install_composio_fresh

install_zip_skill() {
  local name="$1"
  local id="$2"
  local target="$HOME/.codex/skills/$name"
  local zip_file

  zip_file="$(mktemp "${TMPDIR:-/tmp}/codex-skill-${name}.XXXXXX.zip")"
  mkdir -p "$target"
  curl -L -o "$zip_file" "https://mcp.directory/api/skills/download/$id"
  unzip -o "$zip_file" -d "$target"
  rm -f "$zip_file"
}

install_npx_skill() {
  local source="$1"
  npx --yes skills@latest add "$source" -g -a codex -y
}

install_npx_repo_skill() {
  local source="$1"
  local skill="$2"
  npx --yes skills@latest add "$source" --skill "$skill" -g -a codex -y
}

install_npx_skill_if_missing() {
  local name="$1"
  local source="$2"

  if [[ -d "$HOME/.agents/skills/$name" || -d "$HOME/.codex/skills/$name" ]]; then
    echo "Codex skill $name already installed."
  else
    install_npx_skill "$source"
  fi
}

install_codex_seo() {
  local installer
  installer="$(mktemp "${TMPDIR:-/tmp}/codex-seo-install.XXXXXX.sh")"
  curl -fsSL -o "$installer" https://raw.githubusercontent.com/AgriciDaniel/codex-seo/v1.9.6-codex.5/install.sh
  bash "$installer"
  rm -f "$installer"
}

echo "Installing Codex skills..."
install_zip_skill "ui-ux-pro-max" "191"
install_npx_repo_skill "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill" "ckm:design"
install_npx_repo_skill "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill" "ckm:banner-design"
install_npx_skill "remotion-dev/skills"
install_npx_skill "gitroomhq/postiz-agent"
install_npx_skill "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/brand-guidelines"
install_npx_skill "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/composio-skills"
install_npx_skill_if_missing "remove-bg-automation" "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/composio-skills/remove-bg-automation"
install_npx_skill_if_missing "google-cloud-vision-automation" "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/composio-skills/google-cloud-vision-automation"
install_npx_skill "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/file-organizer"
install_npx_skill "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/lead-research-assistant"
install_npx_skill "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/theme-factory"
install_codex_seo

echo
echo "Done."
echo "Versions:"
python3 --version || true
node --version || true
npm --version || true
codex --version || true
ffmpeg -version | head -n 1 || true
magick --version | head -n 1 || true
gs --version || true

echo
echo "Remotion is usually created per project. Start a new Remotion project with:"
echo "  npx create-video@latest"
echo
echo "Docs: https://www.remotion.dev/docs"
echo "Restart Codex after installing or updating skills."
