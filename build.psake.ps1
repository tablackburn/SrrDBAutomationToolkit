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

# Note: -Depends replaces PowerShellBuild's default dependencies, so we must include Pester and Analyze explicitly
Task -Name 'Test' -FromModule 'PowerShellBuild' -MinimumVersion '0.7.3' -Depends 'Init_Integration', 'Pester', 'Analyze'
