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
    # Point PSScriptAnalyzer at this repository's settings file.
    #
    # PowerShellBuild's default SettingsPath is
    # Join-Path $PSScriptRoot 'ScriptAnalyzerSettings.psd1' where $PSScriptRoot is
    # PowerShellBuild's own module directory -- so without this line the analyzer
    # runs against the settings bundled with PowerShellBuild and the
    # PSScriptAnalyzerSettings.psd1 in this repository is never read. Note the
    # filenames differ too, so the default cannot pick it up by accident.
    $PSBPreference.Test.ScriptAnalysis.SettingsPath =
        Join-Path -Path $PSScriptRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'
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

# Custom Pester task, used instead of PowerShellBuild's built-in 'Pester' task.
#
# Two separate reasons it exists.
#
# 1. Version agreement. PowerShellBuild's Test-PSBuildPester runs
#    `Import-Module Pester -MinimumVersion 5.0.0`, which resolves to the *highest*
#    installed version. Pester 6 also re-resolves Describe by autoloading during
#    its per-file discovery, and autoload likewise picks the highest installed
#    version -- so an exact pin is never actually honoured. Whenever the runner
#    image ships something newer than the pin, the two collide:
#
#      An incompatible version of the Pester.dll assembly is already loaded.
#
#    Pester 6.0.1 arrived 2026-07-18 and 6.1.0 on 2026-08-11, breaking CI both
#    times with no commit to blame. build.depend.psd1 therefore uses
#    Version = 'latest' and this task imports the highest installed version, so
#    PSDepend, this task and Pester's autoload all agree and cannot collide.
#    Do not narrow either back to an exact version without changing the other.
#
# 2. Failed containers. PowerShellBuild's gate throws only on FailedCount, which
#    cannot see a test file that died during discovery -- it generates no tests
#    at all, so zero failures reads as success. See the gate below.
$unitTestPreReqs = {
    # A psake PreCondition returning $false *skips* the task and lets the build succeed.
    # That is the right behaviour for testing being deliberately switched off, and exactly
    # the wrong behaviour for a missing test directory -- 'Test' would pass having run
    # nothing at all. So only Test.Enabled may skip; anything else throws.
    if (-not $PSBPreference.Test.Enabled) {
        Write-Warning 'Pester testing is not enabled; skipping UnitTest.'
        return $false
    }

    if (-not (Test-Path -Path $PSBPreference.Test.RootDir)) {
        throw "Test directory [$($PSBPreference.Test.RootDir)] not found, but testing is enabled. Refusing to report success without running tests."
    }

    return $true
}

# Depends on 'Build' because $PSBPreference.Build.ModuleOutDir is only populated once
# PowerShellBuild's Build task has run and staged the module.
Task -Name 'UnitTest' -Depends 'Build' -PreCondition $unitTestPreReqs -Description 'Execute Pester tests, failing on failed containers as well as failed tests' {
    # build.depend.psd1 is the single source of truth for the Pester version.
    $dependencyFile = Join-Path -Path $PSScriptRoot -ChildPath 'build.depend.psd1'
    $pesterVersion = (Import-PowerShellDataFile -Path $dependencyFile).Pester.Version

    if ($pesterVersion -and $pesterVersion -ne 'latest') {
        Import-Module -Name 'Pester' -RequiredVersion $pesterVersion -Force -ErrorAction 'Stop'
    }
    else {
        # With 'latest', import the newest installed version. That is also what Pester's
        # own autoloading resolves to when it re-resolves Describe during per-file
        # discovery -- keeping the two in agreement is precisely what avoids the
        # assembly collision, so do not narrow this to a specific version.
        $newestPester = Get-Module -Name 'Pester' -ListAvailable |
            Sort-Object -Property 'Version' -Descending |
            Select-Object -First 1
        if (-not $newestPester) {
            throw 'Pester is not installed.'
        }

        # Import by path, not by -Name $newestPester. A PSModuleInfo stringifies to
        # its Name, so -Name would import 'Pester' by name and resolve the version
        # itself -- and if an incompatible Pester is already loaded that re-raises
        # the very collision this task exists to prevent:
        #
        #   An incompatible version of the Pester.dll assembly is already loaded.
        #
        # Verified against 5.7.1 preloaded: -Name left the session on 5.7.1.
        # Unload first so the selected version is the only one in play.
        Get-Module -Name 'Pester' | Remove-Module -Force -ErrorAction 'SilentlyContinue'
        Import-Module -Name $newestPester.Path -Force -ErrorAction 'Stop'
    }
    Write-Verbose "Using Pester $((Get-Module -Name 'Pester').Version)" -Verbose

    # Remove any previously imported project module and import from the output dir
    $moduleManifest = Join-Path -Path $PSBPreference.Build.ModuleOutDir -ChildPath "$($PSBPreference.General.ModuleName).psd1"
    Get-Module -Name $PSBPreference.General.ModuleName | Remove-Module -Force -ErrorAction 'SilentlyContinue'
    # -ErrorAction Stop so a non-terminating import error fails here rather than letting
    # the run continue into Pester against a module that was never loaded.
    Import-Module -Name $moduleManifest -Force -ErrorAction 'Stop'

    Push-Location -LiteralPath $PSBPreference.Test.RootDir

    try {
        $configuration = [PesterConfiguration]::Default
        $configuration.Output.Verbosity = 'Detailed'
        $configuration.Run.PassThru = $true
        $configuration.Run.Path = $PSBPreference.Test.RootDir
        $configuration.TestResult.Enabled = -not [string]::IsNullOrEmpty($PSBPreference.Test.OutputFile)
        $configuration.TestResult.OutputPath = $PSBPreference.Test.OutputFile
        $configuration.TestResult.OutputFormat = $PSBPreference.Test.OutputFormat

        if ($PSBPreference.Test.CodeCoverage.Enabled) {
            $configuration.CodeCoverage.Enabled = $true
            # Pester 6 defaults CoveragePercentTarget to 75; this project sets the
            # threshold to 0 and enforces coverage via Codecov instead. Carry the
            # configured value across or the default silently reintroduces a gate.
            #
            # The two use different units: PowerShellBuild's Threshold is a fraction
            # ("Threshold required to pass code coverage test (.90 = 90%)"), while
            # Pester's CoveragePercentTarget is a percentage. Assigning one to the
            # other unconverted is a no-op at 0, but would turn a later 0.90 into
            # 0.9% and quietly disable the gate.
            $configuration.CodeCoverage.CoveragePercentTarget = [double]$PSBPreference.Test.CodeCoverage.Threshold * 100
            if ($PSBPreference.Test.CodeCoverage.Files.Count -gt 0) {
                $configuration.CodeCoverage.Path = $PSBPreference.Test.CodeCoverage.Files
            }
            $configuration.CodeCoverage.OutputPath = $PSBPreference.Test.CodeCoverage.OutputFile
            $configuration.CodeCoverage.OutputFormat = $PSBPreference.Test.CodeCoverage.OutputFileFormat
        }

        $testResult = Invoke-Pester -Configuration $configuration

        # FailedCount alone is not enough. When a file fails during discovery -- for
        # example an empty -ForEach under Pester 6 -- Pester fails the whole container
        # and it generates no tests at all: zero passed, zero failed. Gating only on
        # FailedCount reports success while that file never ran, which is how ~777
        # tests sat silently disabled in PlexAutomationToolkit.
        # Use FailedContainersCount, not `Containers | Where-Object { -not $_.Passed }`.
        # A container that dies during discovery still reports Passed = $true on the
        # container object, so filtering on it silently matches nothing -- reproducing
        # the exact bug this check exists to catch. FailedContainersCount is the
        # property Pester actually maintains.
        if ($testResult.FailedContainersCount -gt 0) {
            $testResult.FailedContainers | ForEach-Object { Write-Warning "Container failed: $($_.Item)" }
            throw "$($testResult.FailedContainersCount) test file(s) failed to run. See 'Container failed' above."
        }

        # Setup/teardown failures are counted separately again. A BeforeAll that throws
        # can leave FailedCount at 0, and a failing AfterAll leaves both FailedCount and
        # FailedContainersCount at 0 while the run still reports passing tests -- verified
        # against Pester 6.1.0:
        #   failing AfterAll -> Failed 0, FailedContainers 0, FailedBlocks 1, Passed 1
        if ($testResult.FailedBlocksCount -gt 0) {
            $testResult.FailedBlocks | ForEach-Object { Write-Warning "Block failed: $($_.Path -join ' > ')" }
            throw "$($testResult.FailedBlocksCount) setup/teardown block(s) failed. See 'Block failed' above."
        }

        if ($testResult.FailedCount -gt 0) {
            throw 'One or more Pester tests failed'
        }

        # A run that executed nothing is not a passing run. Every gate above counts
        # failures, and a run with no executed tests produces zero of all of them.
        #
        # Two distinct ways to get there, and TotalCount alone only catches the first:
        #   1. Nothing discovered -- a bad Run.Path, or a tests directory that stopped
        #      matching *.Tests.ps1. TotalCount is 0.
        #   2. Everything discovered but nothing run -- an over-eager filter. Measured
        #      against Pester 6.1.0 with a filter matching no test name:
        #        Passed 0 | Failed 0 | Skipped 0 | NotRun 120 | TotalCount 120
        #      TotalCount is non-zero, every failure count is 0, and the build passed.
        #
        # Test.Enabled is the deliberate opt-out and is handled in the PreCondition;
        # reaching here having run nothing is a fault either way.
        # Count tests that actually produced a result. Measured against Pester 6.1.0,
        # three ways to reach "nothing ran" that every failure count reads as success:
        #
        #   empty test directory     -> Total 0,   Passed 0, Failed 0, Skipped 0, NotRun 0
        #   filter matching no test  -> Total 120, Passed 0, Failed 0, Skipped 0, NotRun 120
        #   every test -Skip         -> Total 3,   Passed 0, Failed 0, Skipped 3, NotRun 0
        #
        # TotalCount minus NotRunCount misses the third, and so does filtering on the
        # per-test .Executed property -- skipped tests report Executed = $true. Only
        # passed-plus-failed distinguishes a suite that ran from one that did not.
        # Casts are deliberate: with nothing discovered these come back null.
        $ranCount = [int]$testResult.PassedCount + [int]$testResult.FailedCount
        if ($ranCount -le 0) {
            $counts = "discovered $([int]$testResult.TotalCount), skipped $([int]$testResult.SkippedCount), not run $([int]$testResult.NotRunCount)"
            throw "Pester ran no tests under [$($PSBPreference.Test.RootDir)] ($counts). Refusing to report success without running tests."
        }
    }
    finally {
        Pop-Location
        Remove-Module -Name $PSBPreference.General.ModuleName -ErrorAction 'SilentlyContinue'
    }
}

# Note: -Depends replaces PowerShellBuild's default dependencies. 'UnitTest' above stands in
# for PowerShellBuild's 'Pester' task; 'Analyze' is still PowerShellBuild's.
Task -Name 'Test' -FromModule 'PowerShellBuild' -MinimumVersion '0.7.3' -Depends 'Init_Integration', 'UnitTest', 'Analyze'
