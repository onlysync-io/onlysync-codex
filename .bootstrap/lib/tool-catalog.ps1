$ErrorActionPreference = "Stop"

$script:UserHome = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { throw "No home directory found." }
$script:BootstrapRoot = Split-Path -Parent $PSScriptRoot
$script:ProjectRoot = Split-Path -Parent $script:BootstrapRoot
$script:ProjectStateDir = Join-Path $script:BootstrapRoot "tool-installs"
$script:ProjectToolsDir = Join-Path $script:BootstrapRoot "tools"
$script:ProjectBinDir = Join-Path $script:ProjectToolsDir "bin"
$script:GlobalToolRoot = Join-Path $script:UserHome ".codex\workbench"
$script:GlobalPythonVenv = Join-Path $script:GlobalToolRoot "python"
$script:GlobalBinDir = Join-Path $script:UserHome ".codex\bin"
$script:GlobalAgentsFile = Join-Path $script:UserHome ".codex\AGENTS.md"
$script:ProjectAgentsFile = Join-Path $script:ProjectRoot "AGENTS.md"
$script:SupportedToolBundles = @("core", "documents", "pdf-images", "diagrams", "browser-automation", "composio-cli")

function Ensure-ToolBaseDirs {
  New-Item -ItemType Directory -Force -Path $script:ProjectStateDir, $script:ProjectToolsDir, $script:ProjectBinDir, $script:GlobalToolRoot, $script:GlobalBinDir | Out-Null
}

function ConvertTo-ShellValue {
  param([string]$Value)

  $escaped = $Value.Replace("'", "'\''")
  return "'$escaped'"
}

function Refresh-SessionPath {
  $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  $combined = @($machinePath, $userPath) -join ";"
  if (-not [string]::IsNullOrWhiteSpace($combined)) {
    $env:Path = $combined
  }
}

function Get-InstalledPythonCommand {
  $candidates = @(@(
    (Join-Path $env:LOCALAPPDATA "Programs\Python\Python312\python.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\Python\Python313\python.exe"),
    (Join-Path $env:ProgramFiles "Python312\python.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Python312\python.exe")
  ) | Where-Object { $_ -and (Test-Path $_) })

  if ($candidates.Count -gt 0) {
    return $candidates[0]
  }

  return $null
}

function Invoke-BootstrapPython {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Arguments
  )

  Refresh-SessionPath

  $installedPython = Get-InstalledPythonCommand
  if ($installedPython) {
    & $installedPython @Arguments
    return
  }

  if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3.12 @Arguments
  } elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
    & python3 @Arguments
  } elseif (Get-Command python -ErrorAction SilentlyContinue) {
    & python @Arguments
  } else {
    throw "No compatible Python launcher was found."
  }
}

function Get-ToolMetadataPath {
  param(
    [string]$Name,
    [string]$Mode
  )

  Join-Path $script:ProjectStateDir "$Mode--$Name.env"
}

function Write-ToolMetadata {
  param(
    [string]$Name,
    [string]$Mode,
    [string]$ScopeSupport,
    [string]$TargetDir,
    [string]$Commands,
    [string]$Packages,
    [string]$Notes
  )

  $lines = @(
    "NAME=$(ConvertTo-ShellValue $Name)"
    "MODE=$(ConvertTo-ShellValue $Mode)"
    "TYPE=$(ConvertTo-ShellValue 'bundle')"
    "SCOPE_SUPPORT=$(ConvertTo-ShellValue $ScopeSupport)"
    "TARGET_DIR=$(ConvertTo-ShellValue $TargetDir)"
    "COMMANDS=$(ConvertTo-ShellValue $Commands)"
    "PACKAGES=$(ConvertTo-ShellValue $Packages)"
    "NOTES=$(ConvertTo-ShellValue $Notes)"
    "UPDATED_AT=$(ConvertTo-ShellValue ((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')))"
  )
  Set-Content -Path (Get-ToolMetadataPath -Name $Name -Mode $Mode) -Value $lines
}

function Read-ToolMetadata {
  param([string]$Path)

  $data = @{}
  foreach ($line in Get-Content $Path) {
    if ($line -match '^(?<key>[^=]+)=(?<value>.*)$') {
      $value = $Matches.value
      if ($value.Length -ge 2 -and $value.StartsWith("'") -and $value.EndsWith("'")) {
        $value = $value.Substring(1, $value.Length - 2)
      } else {
        $value = $value.Replace('\ ', ' ').Replace('\,', ',').Replace('\|', '|').Replace('\\', '\')
      }
      $data[$Matches.key] = $value
    }
  }
  return $data
}

function Get-CanonicalToolMetadataPath {
  param(
    [string]$Name,
    [string]$Mode
  )

  Join-Path $script:ProjectStateDir "$Mode--$Name.env"
}

function Get-SelectedToolMetadata {
  param([string]$ModeFilter = "")

  $selected = @{}
  $stale = @()
  $files = if ([System.IO.Directory]::Exists($script:ProjectStateDir)) {
    [System.IO.Directory]::GetFiles($script:ProjectStateDir, '*.env') |
      Sort-Object |
      ForEach-Object { [System.IO.FileInfo]::new($_) }
  } else {
    @()
  }

  foreach ($file in $files) {
    $meta = Read-ToolMetadata $file.FullName
    if (-not $meta['NAME'] -or -not $meta['MODE']) { continue }
    if ($ModeFilter -and $meta['MODE'] -ne $ModeFilter) { continue }

    $key = "$($meta['MODE'])::$($meta['NAME'])"
    $canonicalPath = Get-CanonicalToolMetadataPath -Name $meta['NAME'] -Mode $meta['MODE']

    if (-not $selected.ContainsKey($key)) {
      $selected[$key] = [pscustomobject]@{ Path = $file.FullName; Meta = $meta }
      continue
    }

    if ($file.FullName -eq $canonicalPath) {
      $stale += $selected[$key].Path
      $selected[$key] = [pscustomobject]@{ Path = $file.FullName; Meta = $meta }
    } else {
      $stale += $file.FullName
    }
  }

  [pscustomobject]@{
    Selected = ($selected.GetEnumerator() | Sort-Object Name | ForEach-Object { $_.Value })
    Stale = ($stale | Sort-Object -Unique)
  }
}

function Ensure-AgentsFile {
  param(
    [string]$Path,
    [string]$Title
  )

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
  if (-not (Test-Path $Path)) {
    Set-Content -Path $Path -Value @(
      '- Always use real umlauts in externally visible text: `ä, ö, ü, Ä, Ö, Ü, ß`.'
      ""
      "## $Title"
    )
  }
}

function Sync-AgentsBlock {
  param(
    [string]$Path,
    [string]$StartMarker,
    [string]$EndMarker,
    [string]$Heading,
    [string[]]$Lines
  )

  Ensure-AgentsFile -Path $Path -Title $Heading
  $existing = if (Test-Path $Path) { Get-Content $Path -Raw } else { "" }
  $managed = @(
    $StartMarker
    "## $Heading"
    ""
  )
  if (-not $Lines -or $Lines.Count -eq 0) {
    $managed += "- none"
  } else {
    $managed += $Lines
  }
  $managed += $EndMarker
  $managedText = ($managed -join "`r`n")
  $pattern = "(?s)$([regex]::Escape($StartMarker)).*?$([regex]::Escape($EndMarker))"

  if ($existing -match $pattern) {
    $updated = [regex]::Replace($existing, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $managedText })
  } else {
    $updated = $existing.TrimEnd() + "`r`n`r`n" + $managedText + "`r`n"
  }
  Set-Content -Path $Path -Value $updated
}

function Sync-GlobalAgentsFile {
  $bundleLines = @()
  $selected = Get-SelectedToolMetadata -ModeFilter "global"
  $bundleCount = $selected.Selected.Count

  $bundleLines += "- Managed by this bootstrap as a compact global reference."
  $bundleLines += "- Recorded global tool bundles: ``$bundleCount``."
  $bundleLines += "- Metadata directory: ``$script:ProjectStateDir``."
  $bundleLines += "- Global workbench root: ``$script:GlobalToolRoot``."
  $bundleLines += "- Inspect the current inventory from ``$script:ProjectRoot`` with ``./scripts/list_tools.sh``."

  Sync-AgentsBlock -Path $script:GlobalAgentsFile -StartMarker "<!-- CODEX_GLOBAL_TOOL_BUNDLES_START -->" -EndMarker "<!-- CODEX_GLOBAL_TOOL_BUNDLES_END -->" -Heading "Managed Global Tool Bundles" -Lines $bundleLines
}

function Sync-ProjectAgentsFile {
  $bundleLines = @()
  $selected = Get-SelectedToolMetadata -ModeFilter "project"

  foreach ($entry in $selected.Selected) {
    $meta = $entry.Meta
    $bundleLines += "- ``$($meta['NAME'])``: Target ``$($meta['TARGET_DIR'])`` | Commands ``$($meta['COMMANDS'])`` | Packages ``$($meta['PACKAGES'])``"
    if ($meta['NOTES']) {
      $bundleLines += "  Note: $($meta['NOTES'])"
    }
  }

  Sync-AgentsBlock -Path $script:ProjectAgentsFile -StartMarker "<!-- CODEX_PROJECT_TOOL_BUNDLES_START -->" -EndMarker "<!-- CODEX_PROJECT_TOOL_BUNDLES_END -->" -Heading "Managed Project Tool Bundles" -Lines $bundleLines
}

function Ensure-GlobalPythonWrappers {
  param([string]$PythonExe)

  Set-Content -Path (Join-Path $script:GlobalBinDir "codex-python.cmd") -Value "@echo off`r`n`"$PythonExe`" %*`r`n"
  Set-Content -Path (Join-Path $script:GlobalBinDir "codex-markitdown.cmd") -Value "@echo off`r`n`"$PythonExe`" -m markitdown %*`r`n"
}

function Ensure-ProjectPythonWrappers {
  param([string]$PythonExe)

  New-Item -ItemType Directory -Force -Path $script:ProjectBinDir | Out-Null
  Set-Content -Path (Join-Path $script:ProjectBinDir "codex-python.cmd") -Value "@echo off`r`n`"$PythonExe`" %*`r`n"
  Set-Content -Path (Join-Path $script:ProjectBinDir "codex-markitdown.cmd") -Value "@echo off`r`n`"$PythonExe`" -m markitdown %*`r`n"
}

function Get-VenvPythonExe {
  param([string]$VenvPath)

  $windowsPath = Join-Path $VenvPath "Scripts\python.exe"
  if (Test-Path $windowsPath) {
    return $windowsPath
  }
  return (Join-Path $VenvPath "bin/python")
}

function Install-DocumentsPythonGlobal {
  Invoke-BootstrapPython -m venv $script:GlobalPythonVenv
  $pythonExe = Get-VenvPythonExe -VenvPath $script:GlobalPythonVenv
  & $pythonExe -m pip install --upgrade pip
  & $pythonExe -m pip install --upgrade openpyxl python-docx python-pptx markitdown pypdf pymupdf
  Ensure-GlobalPythonWrappers -PythonExe $pythonExe
}

function Install-DocumentsPythonProject {
  $runtimeRoot = Join-Path $script:ProjectToolsDir "documents"
  $venvPath = Join-Path $runtimeRoot "python"
  New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
  Invoke-BootstrapPython -m venv $venvPath
  $pythonExe = Get-VenvPythonExe -VenvPath $venvPath
  & $pythonExe -m pip install --upgrade pip
  & $pythonExe -m pip install --upgrade openpyxl python-docx python-pptx markitdown pypdf pymupdf
  Ensure-ProjectPythonWrappers -PythonExe $pythonExe
}

function Install-DocumentsNodeGlobal {
  npm install -g mammoth docx xlsx pptxgenjs pdf-parse
}

function Install-DocumentsNodeProject {
  $runtimeRoot = Join-Path $script:ProjectToolsDir "documents"
  New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
  if (-not (Test-Path (Join-Path $runtimeRoot "package.json"))) {
    npm init -y --prefix $runtimeRoot *> $null
  }
  npm install --prefix $runtimeRoot mammoth docx xlsx pptxgenjs pdf-parse *> $null
}

function Install-BrowserAutomationProject {
  $runtimeRoot = Join-Path $script:ProjectToolsDir "browser-automation"
  New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
  if (-not (Test-Path (Join-Path $runtimeRoot "package.json"))) {
    npm init -y --prefix $runtimeRoot *> $null
  }
  npm install --prefix $runtimeRoot playwright *> $null
  npx --prefix $runtimeRoot playwright install *> $null
  Set-Content -Path (Join-Path $script:ProjectBinDir "codex-playwright.cmd") -Value "@echo off`r`nnpx --prefix `"$runtimeRoot`" playwright %*`r`n"
}

function Install-ComposioCliGlobal {
  npm install -g @composio/cli
}

function Install-ToolBundle {
  param(
    [string]$Name,
    [string]$Mode
  )

  switch ($Name) {
    "core" {
      if ($Mode -eq "project") { throw "Bundle 'core' supports global mode only." }
      winget install --id "Python.Python.3.12" --exact --source winget --accept-package-agreements --accept-source-agreements
      winget install --id "OpenJS.NodeJS.LTS" --exact --source winget --accept-package-agreements --accept-source-agreements
      winget install --id "Git.Git" --exact --source winget --accept-package-agreements --accept-source-agreements
      winget install --id "BurntSushi.ripgrep.MSVC" --exact --source winget --accept-package-agreements --accept-source-agreements
      Invoke-BootstrapPython -m pip install --upgrade pip pipx
      pipx ensurepath
      Write-ToolMetadata -Name $Name -Mode $Mode -ScopeSupport "global_only" -TargetDir "$env:ProgramFiles;$env:USERPROFILE\.codex\bin" -Commands "python,node,npm,git,rg,pipx" -Packages "winget:python,node,git,ripgrep|pip:pipx" -Notes "Core system tools are installed globally only."
    }
    "documents" {
      if ($Mode -eq "global") {
        winget install --id "JohnMacFarlane.Pandoc" --exact --source winget --accept-package-agreements --accept-source-agreements *> $null
        Install-DocumentsPythonGlobal
        Install-DocumentsNodeGlobal
        Write-ToolMetadata -Name $Name -Mode $Mode -ScopeSupport "global_or_project" -TargetDir $script:GlobalPythonVenv -Commands "codex-python,codex-markitdown,pandoc" -Packages "winget:pandoc|python:openpyxl,python-docx,python-pptx,markitdown,pypdf,pymupdf|npm:mammoth,docx,xlsx,pptxgenjs,pdf-parse" -Notes "Global document workbench for Office generation, extraction, and PDF parsing, including PyMuPDF and Node document parsers and generators."
        Sync-GlobalAgentsFile
      } else {
        Install-DocumentsPythonProject
        Install-DocumentsNodeProject
        $projectCommands = "$(Join-Path $script:ProjectBinDir 'codex-python.cmd'),$(Join-Path $script:ProjectBinDir 'codex-markitdown.cmd')"
        Write-ToolMetadata -Name $Name -Mode $Mode -ScopeSupport "global_or_project" -TargetDir (Join-Path $script:ProjectToolsDir "documents") -Commands $projectCommands -Packages "python:openpyxl,python-docx,python-pptx,markitdown,pypdf,pymupdf|npm:mammoth,docx,xlsx,pptxgenjs,pdf-parse" -Notes "Workspace mode creates a local document runtime with Python and Node packages. Pandoc remains a globally preferred native tool."
      }
    }
    "pdf-images" {
      if ($Mode -eq "project") { throw "Bundle 'pdf-images' supports global mode only." }
      winget install --id "Gyan.FFmpeg" --exact --source winget --accept-package-agreements --accept-source-agreements
      winget install --id "ImageMagick.ImageMagick" --exact --source winget --accept-package-agreements --accept-source-agreements
      winget install --id "ArtifexSoftware.GhostScript" --exact --source winget --accept-package-agreements --accept-source-agreements
      Write-ToolMetadata -Name $Name -Mode $Mode -ScopeSupport "global_only" -TargetDir "$env:ProgramFiles" -Commands "ffmpeg,magick,gswin64c" -Packages "winget:ffmpeg,imagemagick,ghostscript" -Notes "Native tools for rendering, conversion, and technical PDF/image work."
    }
    "diagrams" {
      if ($Mode -eq "project") { throw "Bundle 'diagrams' supports global mode only." }
      winget install --id "JGraph.Draw" --exact --source winget --accept-package-agreements --accept-source-agreements
      Write-ToolMetadata -Name $Name -Mode $Mode -ScopeSupport "global_only" -TargetDir "$env:ProgramFiles" -Commands "draw.io" -Packages "winget:draw.io" -Notes "Draw.io remains a globally installed native diagramming tool."
    }
    "browser-automation" {
      if ($Mode -eq "global") {
        npm install -g pnpm playwright
        npx -y playwright install
        Write-ToolMetadata -Name $Name -Mode $Mode -ScopeSupport "global_or_project" -TargetDir $script:GlobalBinDir -Commands "pnpm,playwright" -Packages "npm:pnpm,playwright" -Notes "Global browser automation via Node tooling."
        Sync-GlobalAgentsFile
      } else {
        Install-BrowserAutomationProject
        Write-ToolMetadata -Name $Name -Mode $Mode -ScopeSupport "global_or_project" -TargetDir (Join-Path $script:ProjectToolsDir "browser-automation") -Commands (Join-Path $script:ProjectBinDir "codex-playwright.cmd") -Packages "npm:playwright" -Notes "Workspace mode creates a local Playwright runtime directory. pnpm remains globally preferred."
      }
    }
    "composio-cli" {
      if ($Mode -eq "project") { throw "Bundle 'composio-cli' supports global mode only." }
      Install-ComposioCliGlobal
      $npmGlobalBin = Join-Path $env:APPDATA "npm"
      Write-ToolMetadata -Name $Name -Mode $Mode -ScopeSupport "global_only" -TargetDir $npmGlobalBin -Commands "composio" -Packages "npm:@composio/cli" -Notes "Composio CLI uses the documented npm fallback on Windows because the official installer targets WSL or Unix-like shells."
    }
    default {
      throw "Unsupported tool bundle: $Name"
    }
  }

  if ($Mode -eq "global") {
    Sync-GlobalAgentsFile
  } else {
    Sync-ProjectAgentsFile
  }
}

function Show-ToolInstallations {
  Write-Host "Managed tool installations:"
  $selected = Get-SelectedToolMetadata
  if (-not $selected.Selected) {
    Write-Host "- none"
    return
  }

  foreach ($entry in $selected.Selected) {
    $meta = $entry.Meta
    Write-Host "- $($meta['NAME']) | Mode: $($meta['MODE']) | Scope: $($meta['SCOPE_SUPPORT']) | Target: $($meta['TARGET_DIR']) | Commands: $($meta['COMMANDS']) | Updated: $($meta['UPDATED_AT'])"
    Write-Host "  Packages: $($meta['PACKAGES'])"
    Write-Host "  Note: $($meta['NOTES'])"
  }

  if ($selected.Stale.Count -gt 0) {
    Write-Host ""
    Write-Host "Ignored stale metadata files:"
    foreach ($path in $selected.Stale) {
      Write-Host "- $path"
    }
  }
}

function Invoke-InstallTools {
  param(
    [string]$Mode,
    [string[]]$Bundles
  )

  Ensure-ToolBaseDirs
  $selectedMode = if ($Mode) { $Mode } else { "global" }
  $selectedBundles = if ($Bundles.Count -eq 1 -and $Bundles[0] -eq "all") { $script:SupportedToolBundles } else { $Bundles }
  foreach ($bundle in $selectedBundles) {
    Write-Host "Installing tool bundle $bundle in $selectedMode mode..."
    Install-ToolBundle -Name $bundle -Mode $selectedMode
  }
  Write-Host ""
  Show-ToolInstallations
}

function Invoke-UpdateTools {
  param([string[]]$Bundles)

  Ensure-ToolBaseDirs
  $selected = Get-SelectedToolMetadata
  $files = if ($Bundles.Count -eq 1 -and $Bundles[0] -eq "all") {
    $selected.Selected
  } else {
    $selected.Selected | Where-Object { $Bundles -contains $_.Meta["NAME"] }
  }
  foreach ($file in $files) {
    $meta = $file.Meta
    Write-Host "Updating $($meta['NAME']) in $($meta['MODE']) mode..."
    Install-ToolBundle -Name $meta['NAME'] -Mode $meta['MODE']
  }
  Write-Host ""
  Show-ToolInstallations
}

function Show-InstalledTools {
  Ensure-ToolBaseDirs
  Show-ToolInstallations
}
