param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $Args
)

$ErrorActionPreference = "Stop"

function Get-BashExecutable {
  $bashCommand = Get-Command bash -ErrorAction SilentlyContinue
  $candidates = @(
    if ($bashCommand) { $bashCommand.Source },
    (Join-Path $env:ProgramFiles "Git\bin\bash.exe"),
    (Join-Path $env:ProgramFiles "Git\usr\bin\bash.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Git\bin\bash.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Git\usr\bin\bash.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\Git\bin\bash.exe")
  ) | Where-Object { $_ -and (Test-Path $_) }

  if ($candidates.Count -gt 0) {
    return $candidates[0]
  }

  throw "No Bash executable was found. Install Git for Windows first, then rerun this script."
}

$bashExe = Get-BashExecutable
$scriptPath = Join-Path $PSScriptRoot "update_skills.sh"

& $bashExe --noprofile --norc $scriptPath @Args
exit $LASTEXITCODE
