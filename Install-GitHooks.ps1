<#
.SYNOPSIS
    Installs git hooks for the repository.

.DESCRIPTION
    Configures git to use the .githooks directory for hooks.
    This enables pre-commit linting with PSScriptAnalyzer.

.EXAMPLE
    ./Install-GitHooks.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "Configuring git hooks..." -ForegroundColor Cyan

git config core.hooksPath .githooks

Write-Host "Git hooks installed successfully!" -ForegroundColor Green
Write-Host "Pre-commit hook will run PSScriptAnalyzer on staged .ps1 files." -ForegroundColor Gray
