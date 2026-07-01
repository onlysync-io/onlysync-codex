$ErrorActionPreference = "Stop"

function Get-BashExecutable {
  $candidates = @(
    (Get-Command bash -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files\Git\usr\bin\bash.exe"
  ) | Where-Object { $_ -and (Test-Path $_) }

  if ($candidates.Count -gt 0) {
    return $candidates[0]
  }

  throw "No Bash executable was found. Install Git for Windows first, then rerun this command."
}

$bashExe = Get-BashExecutable
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$shellScript = Join-Path $scriptDir "cdx"

& $bashExe --noprofile --norc $shellScript @Args
