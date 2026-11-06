[CmdletBinding()]
param(
    [string]$Target,
    [switch]$Codex
)

$ErrorActionPreference = 'Stop'

# This installer is intentionally user-scoped. It never requests elevation or
# relaunches itself with administrator privileges.

if ($Target -and $Codex) {
    throw 'Use either -Target or -Codex, not both.'
}

$scriptRoot = $PSScriptRoot

if ($Target) {
    $targetRoot = $Target
} elseif ($Codex) {
    $codexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
    $targetRoot = Join-Path $codexRoot 'skills'
} elseif ($env:SKILLS_HOME) {
    $targetRoot = $env:SKILLS_HOME
} else {
    $targetRoot = Join-Path $HOME '.agents/skills'
}

try {
    New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
    $writeProbe = Join-Path $targetRoot ".coding-convention-write-test-$PID"
    New-Item -ItemType File -Path $writeProbe -Force | Out-Null
    Remove-Item -LiteralPath $writeProbe -Force
} catch {
    throw "Cannot write to '$targetRoot' with the current user account. Choose a user-owned path with -Target or SKILLS_HOME; this installer will not request administrator access. $($_.Exception.Message)"
}

$skillDirectories = @(Get-ChildItem -Path $scriptRoot -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName 'SKILL.md')
})

if (-not $skillDirectories) {
    throw "No skill directories containing SKILL.md were found in $scriptRoot"
}

foreach ($skillDirectory in $skillDirectories) {
    $destination = Join-Path $targetRoot $skillDirectory.Name
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Get-ChildItem -Path $skillDirectory.FullName -Force |
        Where-Object { $_.Name -ne '.DS_Store' } |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
        }
    Write-Host "Installed $($skillDirectory.Name) -> $destination"
}

Write-Host "Installed $($skillDirectories.Count) skill(s) into $targetRoot without administrator access."
