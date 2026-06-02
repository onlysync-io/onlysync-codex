$ErrorActionPreference = "Stop"

Write-Host "Setting up Python 3, Node.js/npm, pnpm, FFmpeg, ImageMagick, Ghostscript, Remotion tooling, Git Bash, Composio, Meta Ads MCP/CLI helpers, MarkItDown MCP, and Codex skills on Windows..."

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw "winget was not found. Install App Installer from the Microsoft Store, then run this script again."
}

function Install-WingetPackage {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Id,

    [Parameter(Mandatory = $true)]
    [string] $Name
  )

  Write-Host "Installing $Name..."
  winget install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements
}

Install-WingetPackage -Id "Python.Python.3.12" -Name "Python 3"
Install-WingetPackage -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS with npm"
Install-WingetPackage -Id "Gyan.FFmpeg" -Name "FFmpeg"
Install-WingetPackage -Id "ImageMagick.ImageMagick" -Name "ImageMagick"
Install-WingetPackage -Id "ArtifexSoftware.GhostScript" -Name "Ghostscript"
Install-WingetPackage -Id "Git.Git" -Name "Git Bash"

Write-Host "Installing Codex CLI..."
npm install -g @openai/codex
npm install -g pnpm

function Add-MemoryMcpConfig {
  $codexDir = Join-Path $HOME ".codex"
  $codexConfig = Join-Path $codexDir "config.toml"

  New-Item -ItemType Directory -Force -Path $codexDir | Out-Null

  if (-not (Test-Path $codexConfig)) {
    New-Item -ItemType File -Path $codexConfig | Out-Null
  }

  $hasMemoryMcp = Select-String -Path $codexConfig -Pattern '^\[mcp_servers\.memory\]' -Quiet

  if (-not $hasMemoryMcp) {
    @"

[mcp_servers.memory]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-memory"]
enabled = true
"@ | Add-Content -Path $codexConfig
  }
}

function Add-MarkItDownMcpConfig {
  $codexDir = Join-Path $HOME ".codex"
  $codexConfig = Join-Path $codexDir "config.toml"

  New-Item -ItemType Directory -Force -Path $codexDir | Out-Null

  if (-not (Test-Path $codexConfig)) {
    New-Item -ItemType File -Path $codexConfig | Out-Null
  }

  $hasMarkItDownMcp = Select-String -Path $codexConfig -Pattern '^\[mcp_servers\.markitdown\]' -Quiet

  if (-not $hasMarkItDownMcp) {
    @"

[mcp_servers.markitdown]
command = "markitdown-mcp"
enabled = true
"@ | Add-Content -Path $codexConfig
  }
}

function Add-MetaAdsMcpConfig {
  $codexDir = Join-Path $HOME ".codex"
  $codexConfig = Join-Path $codexDir "config.toml"
  $url = "https://mcp.facebook.com/ads"

  New-Item -ItemType Directory -Force -Path $codexDir | Out-Null

  if (-not (Test-Path $codexConfig)) {
    New-Item -ItemType File -Path $codexConfig | Out-Null
  }

  $lines = Get-Content -Path $codexConfig -ErrorAction SilentlyContinue
  $output = New-Object System.Collections.Generic.List[string]
  $inSection = $false
  $found = $false

  foreach ($line in $lines) {
    if ($line -match '^\[mcp_servers\.meta_ads\]$') {
      $output.Add('[mcp_servers.meta_ads]')
      $output.Add("url = ""$url""")
      $inSection = $true
      $found = $true
      continue
    }

    if ($inSection -and $line -match '^\[.*\]$') {
      $inSection = $false
    }

    if (-not $inSection) {
      $output.Add($line)
    }
  }

  if (-not $found) {
    if ($output.Count -gt 0 -and $output[$output.Count - 1] -ne "") {
      $output.Add("")
    }
    $output.Add('[mcp_servers.meta_ads]')
    $output.Add("url = ""$url""")
  }

  Set-Content -Path $codexConfig -Value $output
}

function Install-MetaAdsCli {
  Write-Host "Installing Meta Ads CLI..."

  try {
    py -3.12 -m pip index versions meta-ads *> $null
    pipx install --force --python "py -3.12" meta-ads
    Write-Host "Meta Ads CLI installed."
  } catch {
    Write-Warning "Meta Ads CLI was not installed because no compatible meta-ads distribution was found or the install failed."
    Write-Warning "The official meta-ads package requires Python 3.12+ and currently ships wheels for CPython 3.12/3.13."
    Write-Warning "The setup date for this check is June 2, 2026."
    Write-Warning "The Meta Ads MCP endpoint was still configured in ~/.codex/config.toml."
  }
}

Write-Host "Installing Memory MCP server..."
npm install -g @modelcontextprotocol/server-memory
Add-MemoryMcpConfig
Add-MetaAdsMcpConfig
Install-MetaAdsCli

Write-Host "Installing ChatGPT Windows app..."
winget install --id=9NT1R1C2HH7J --source=msstore --accept-package-agreements --accept-source-agreements --silent

Write-Host "Installing Python packages..."
python -m pip install --upgrade holidays pillow rembg markitdown-mcp
Add-MarkItDownMcpConfig

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath"

$bashCandidates = @(
  "$env:ProgramFiles\Git\bin\bash.exe",
  "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
) | Where-Object { $_ -and (Test-Path $_) }

if ($bashCandidates.Count -eq 0) {
  throw "Git Bash was installed, but bash.exe was not found. Open a new PowerShell window and run this script again."
}

$bash = $bashCandidates[0]

Write-Host "Installing Composio through Git Bash..."
New-Item -ItemType Directory -Force -Path (Join-Path $HOME ".composio") | Out-Null
@(
  "composio",
  "composio.exe",
  "release-tag.txt",
  "update-check.json"
) | ForEach-Object {
  $path = Join-Path (Join-Path $HOME ".composio") $_
  if (Test-Path $path) {
    Remove-Item $path -Force
  }
}
& $bash -lc "curl -fsSL https://composio.dev/install | bash"

$composioDir = Join-Path $HOME ".composio"
$releaseTagPath = Join-Path $composioDir "release-tag.txt"
$updateCheckPath = Join-Path $composioDir "update-check.json"
$composioBinary = @(
  (Join-Path $composioDir "composio.exe"),
  (Join-Path $composioDir "composio")
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($composioBinary -and (Test-Path $releaseTagPath)) {
  $releaseTag = (Get-Content -Path $releaseTagPath -Raw).Trim()
  $latestVersion = ($releaseTag -split '@')[-1]
  $versionOutput = & $composioBinary --version 2>$null
  $installedVersionLine = $versionOutput | Where-Object { $_.Trim() } | Select-Object -Last 1
  $installedVersion = if ($installedVersionLine) { $installedVersionLine.Trim() } else { "" }

  if ($latestVersion -and $installedVersion -and ($latestVersion -ne $installedVersion)) {
    Write-Warning "Composio installer fetched $latestVersion, but the binary reports $installedVersion."
    Write-Warning "Removing Composio version markers so future upgrades do not treat the stale binary as current."
    Remove-Item $releaseTagPath -Force
    if (Test-Path $updateCheckPath) {
      Remove-Item $updateCheckPath -Force
    }
  }
}

function Install-ZipSkill {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Name,

    [Parameter(Mandatory = $true)]
    [string] $Id
  )

  $target = Join-Path $HOME ".codex\skills\$Name"
  $zipFile = Join-Path ([System.IO.Path]::GetTempPath()) "codex-skill-$Name.zip"

  Write-Host "Installing Codex skill $Name..."
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  Invoke-WebRequest -Uri "https://mcp.directory/api/skills/download/$Id" -OutFile $zipFile
  Expand-Archive -Path $zipFile -DestinationPath $target -Force
  Remove-Item $zipFile -Force
}

function Install-NpxSkill {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Source
  )

  Write-Host "Installing Codex skill from $Source..."
  npx --yes skills@latest add $Source -g -a codex -y
}

function Install-NpxRepoSkill {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Source,

    [Parameter(Mandatory = $true)]
    [string] $Skill
  )

  Write-Host "Installing Codex skill $Skill from $Source..."
  npx --yes skills@latest add $Source --skill $Skill -g -a codex -y
}

function Install-NpxSkillIfMissing {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Name,

    [Parameter(Mandatory = $true)]
    [string] $Source
  )

  $agentsTarget = Join-Path (Join-Path $HOME ".agents\skills") $Name
  $codexTarget = Join-Path (Join-Path $HOME ".codex\skills") $Name

  if ((Test-Path $agentsTarget) -or (Test-Path $codexTarget)) {
    Write-Host "Codex skill $Name already installed."
  } else {
    Install-NpxSkill -Source $Source
  }
}

function Install-CodexSeo {
  Write-Host "Installing Codex SEO..."
  Invoke-RestMethod "https://raw.githubusercontent.com/AgriciDaniel/codex-seo/v1.9.6-codex.5/install.ps1" | Invoke-Expression
}

Write-Host "Installing Codex skills..."
Install-ZipSkill -Name "ui-ux-pro-max" -Id "191"
Install-NpxRepoSkill -Source "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill" -Skill "ckm:design"
Install-NpxRepoSkill -Source "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill" -Skill "ckm:banner-design"
Install-NpxSkill -Source "remotion-dev/skills"
Install-NpxSkill -Source "gitroomhq/postiz-agent"
Install-NpxSkill -Source "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/brand-guidelines"
Install-NpxSkill -Source "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/composio-skills"
Install-NpxSkillIfMissing -Name "remove-bg-automation" -Source "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/composio-skills/remove-bg-automation"
Install-NpxSkillIfMissing -Name "google-cloud-vision-automation" -Source "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/composio-skills/google-cloud-vision-automation"
Install-NpxSkill -Source "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/file-organizer"
Install-NpxSkill -Source "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/lead-research-assistant"
Install-NpxSkill -Source "https://github.com/ComposioHQ/awesome-codex-skills/tree/master/theme-factory"
Install-CodexSeo

Write-Host ""
Write-Host "Done."
Write-Host "Versions:"
python --version
node --version
npm --version
codex --version
ffmpeg -version | Select-Object -First 1
magick --version | Select-Object -First 1
gswin64c --version

Write-Host ""
Write-Host "Remotion is usually created per project. Start a new Remotion project with:"
Write-Host "  npx create-video@latest"
Write-Host ""
Write-Host "Docs: https://www.remotion.dev/docs"
Write-Host "Restart Codex after installing or updating skills."
