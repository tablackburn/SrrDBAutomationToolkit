param()

# Allow end users to add their own custom psake tasks
$customPsakeFile = Join-Path -Path $PSScriptRoot -ChildPath 'custom.psake.ps1'
if (Test-Path -Path $customPsakeFile) {
    Include -FileNamePathToInclude $customPsakeFile
}

properties {
    # Set this to $true to create a module with a monolithic PSM1
    $PSBPreference.Build.CompileModule = $false
    $PSBPreference.Help.DefaultLocale = 'en-US'
    # Use absolute paths for test output (relative paths resolve from tests directory)
    $PSBPreference.Test.OutputFile = [IO.Path]::Combine($PSScriptRoot, 'out', 'testResults.xml')
    $PSBPreference.Test.OutputFormat = 'NUnitXml'
    $PSBPreference.Test.CodeCoverage.Enabled = $true
    # Coverage must target the staged build output, not the source tree — tests
    # Import-Module from Output/<Name>/<Version>, so Pester only records hits
    # against those paths. $Env:BHBuildOutput points at <root>/BuildOutput at
    # properties-evaluation time (PowerShellBuild rewrites it later inside its
    # tasks), so we compute the staged path from the manifest version here.
    if (-not $Env:BHPSModuleManifest -or -not $Env:BHProjectName) {
        throw 'Coverage configuration requires BuildHelpers env vars. Run via ./build.ps1 or call Set-BuildEnvironment first.'
    }
    $moduleVersion = (Import-PowerShellDataFile -Path $Env:BHPSModuleManifest).ModuleVersion
    $stagedOutput = [IO.Path]::Combine($PSScriptRoot, 'Output', $Env:BHProjectName, $moduleVersion)
    $PSBPreference.Test.CodeCoverage.Files = @(
        "$stagedOutput/Public/*.ps1"
        "$stagedOutput/Private/*.ps1"
    )
    $PSBPreference.Test.CodeCoverage.Threshold = 0  # Threshold enforced by Codecov
    $PSBPreference.Test.CodeCoverage.OutputFile = [IO.Path]::Combine($PSScriptRoot, 'out', 'codeCoverage.xml')
    $PSBPreference.Test.CodeCoverage.OutputFileFormat = 'JaCoCo'
}

Task -Name 'Default' -Depends 'Test'

Task -Name 'Init_Integration' -Description 'Load integration test environment variables from local.settings.ps1' {
    $localSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath 'tests/local.settings.ps1'
    if (Test-Path -Path $localSettingsPath) {
        Write-Host "Loading integration test settings from tests/local.settings.ps1" -ForegroundColor Cyan
        . $localSettingsPath
    } else {
        Write-Host "No local.settings.ps1 found - integration tests will be skipped" -ForegroundColor Yellow
    }
}

# Populate the built manifest's ReleaseNotes from the matching CHANGELOG.md entry so the
# PowerShell Gallery release-notes panel shows the curated, user-facing notes (the same
# content used for the GitHub release) instead of just a link. Depends on Build so the
# staged manifest in ModuleOutDir exists; runs before Publish (see $PSBPublishDependency
# below). Non-fatal at every step so a release is never blocked.
Task -Name 'UpdateReleaseNotes' -Depends 'Build' -Description 'Set built manifest ReleaseNotes from the matching CHANGELOG.md entry' {
    $changelogPath = Join-Path -Path $PSScriptRoot -ChildPath 'CHANGELOG.md'
    if (-not (Test-Path -Path $changelogPath)) {
        Write-Warning 'CHANGELOG.md not found; leaving ReleaseNotes unchanged.'
        return
    }

    $moduleVersion = $PSBPreference.General.ModuleVersion
    try {
        Import-Module -Name 'ChangelogManagement' -ErrorAction Stop
        $changelogData = Get-ChangelogData -Path $changelogPath -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not read CHANGELOG.md ($($_.Exception.Message)); leaving ReleaseNotes unchanged."
        return
    }

    $releaseEntry = $changelogData.Released |
        Where-Object { [string]$_.Version -eq [string]$moduleVersion } |
        Select-Object -First 1
    if (-not $releaseEntry) {
        Write-Warning "No CHANGELOG.md entry found for version $moduleVersion; leaving ReleaseNotes unchanged."
        return
    }

    $releaseNotes = $releaseEntry.RawData.Trim()
    if ([string]::IsNullOrWhiteSpace($releaseNotes)) {
        Write-Warning "CHANGELOG.md entry for version $moduleVersion is empty; leaving ReleaseNotes unchanged."
        return
    }
    $builtManifest = Join-Path -Path $PSBPreference.Build.ModuleOutDir -ChildPath "$($PSBPreference.General.ModuleName).psd1"
    if (-not (Test-Path -Path $builtManifest)) {
        Write-Warning "Built manifest not found at '$builtManifest'; leaving ReleaseNotes unchanged."
        return
    }
    try {
        Update-ModuleManifest -Path $builtManifest -ReleaseNotes $releaseNotes -ErrorAction Stop
        Write-Host "  Set ReleaseNotes on built manifest from CHANGELOG [$($releaseEntry.Version)] ($($releaseNotes.Length) chars)" -ForegroundColor Gray
    }
    catch {
        # Keep publishing unblocked: a failure here just leaves the manifest's existing
        # ReleaseNotes in place rather than aborting the release.
        Write-Warning "Failed to set ReleaseNotes on the built manifest '$builtManifest' ($($_.Exception.Message)); leaving it unchanged."
    }
}

# Inject ReleaseNotes into the built manifest before publishing (PowerShellBuild's Publish
# defaults to depending only on 'Test').
$PSBPublishDependency = @('Test', 'UpdateReleaseNotes')

# Note: -Depends replaces PowerShellBuild's default dependencies, so we must include Pester and Analyze explicitly
Task -Name 'Test' -FromModule 'PowerShellBuild' -MinimumVersion '0.7.3' -Depends 'Init_Integration', 'Pester', 'Analyze'
