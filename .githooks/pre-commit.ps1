#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    Pre-commit hook to run PSScriptAnalyzer on staged PowerShell files.
#>

$ErrorActionPreference = 'Stop'

# Get staged .ps1 files
$stagedFiles = git diff --cached --name-only --diff-filter=ACM | Where-Object { $_ -match '\.ps1$' }

if (-not $stagedFiles) {
    exit 0
}

Write-Host "Running PSScriptAnalyzer on staged files..." -ForegroundColor Cyan

# Ensure PSScriptAnalyzer is available
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host "PSScriptAnalyzer not found. Install with: Install-Module PSScriptAnalyzer" -ForegroundColor Yellow
    exit 0
}

$hasErrors = $false

foreach ($file in $stagedFiles) {
    if (Test-Path $file) {
        $results = Invoke-ScriptAnalyzer -Path $file -Severity Error, Warning -ExcludeRule PSUseShouldProcessForStateChangingFunctions

        if ($results) {
            Write-Host "`nIssues in ${file}:" -ForegroundColor Red
            $results | ForEach-Object {
                Write-Host "  Line $($_.Line): [$($_.Severity)] $($_.RuleName) - $($_.Message)" -ForegroundColor Yellow
            }
            $hasErrors = $true
        }
    }
}

if ($hasErrors) {
    Write-Host "`nCommit blocked due to PSScriptAnalyzer issues." -ForegroundColor Red
    Write-Host "Fix the issues above or use 'git commit --no-verify' to bypass." -ForegroundColor Yellow
    exit 1
}

Write-Host "All checks passed!" -ForegroundColor Green
exit 0
