# spell-checker:ignore BHPS oneline
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    'changelogVersion',
    Justification = 'false positive'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    'manifestData',
    Justification = 'false positive'
)]
param()

BeforeDiscovery {
    <# Check if the BHBuildOutput environment variable exists to determine if this test is running in a psake
    build or not. If it does not exist, it is not running in a psake build, so build the module.
    If the BHBuildOutput environment variable exists, it is running in a psake build, so do not
    build the module. #>
    if ($null -eq $Env:BHBuildOutput) {
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\build.psake.ps1'
        $invokePsakeParameters = @{
            TaskList  = 'Build'
            BuildFile = $buildFilePath
        }
        Invoke-psake @invokePsakeParameters
    }

    # PowerShellBuild outputs to Output/<ModuleName>/<Version>/, override BHBuildOutput
    $projectRoot = Split-Path -Parent $PSScriptRoot
    $sourceManifest = Join-Path $projectRoot "$Env:BHProjectName/$Env:BHProjectName.psd1"
    $moduleVersion = (Import-PowerShellDataFile -Path $sourceManifest).ModuleVersion
    $Env:BHBuildOutput = Join-Path $projectRoot "Output/$Env:BHProjectName/$moduleVersion"

    # Define the path to the module manifest
    $moduleManifestFilename = $Env:BHProjectName + '.psd1'
    $moduleManifestPath = Join-Path -Path $Env:BHBuildOutput -ChildPath $moduleManifestFilename

    # Get the data from the module manifest
    $testModuleManifestParameters = @{
        Path          = $moduleManifestPath
        ErrorAction   = 'Stop'
        WarningAction = 'SilentlyContinue'
    }
    $manifestData = Test-ModuleManifest @testModuleManifestParameters
}
BeforeAll {
    <# Check if the BHBuildOutput environment variable exists to determine if this test is running in a psake
    build or not. If it does not exist, it is not running in a psake build, so build the module.
    If the BHBuildOutput environment variable exists, it is running in a psake build, so do not
    build the module. #>
    if ($null -eq $Env:BHBuildOutput) {
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\build.psake.ps1'
        $invokePsakeParameters = @{
            TaskList  = 'Build'
            BuildFile = $buildFilePath
        }
        Invoke-psake @invokePsakeParameters
    }

    # PowerShellBuild outputs to Output/<ModuleName>/<Version>/, override BHBuildOutput
    $projectRoot = Split-Path -Parent $PSScriptRoot
    $sourceManifest = Join-Path $projectRoot "$Env:BHProjectName/$Env:BHProjectName.psd1"
    $moduleVersion = (Import-PowerShellDataFile -Path $sourceManifest).ModuleVersion
    $Env:BHBuildOutput = Join-Path $projectRoot "Output/$Env:BHProjectName/$moduleVersion"

    # Define the path to the module manifest
    $moduleManifestFilename = $Env:BHProjectName + '.psd1'
    $moduleManifestPath = Join-Path -Path $Env:BHBuildOutput -ChildPath $moduleManifestFilename

    # Get the data from the module manifest
    $testModuleManifestParameters = @{
        Path          = $moduleManifestPath
        ErrorAction   = 'Stop'
        WarningAction = 'SilentlyContinue'
    }
    $manifestData = Test-ModuleManifest @testModuleManifestParameters

    # Parse the version from the changelog
    $changelogPath = Join-Path -Path $Env:BHProjectPath -ChildPath 'CHANGELOG.md'
    $changelogVersionPattern = '^##\s\\?\[(?<Version>(\d+\.){1,3}\d+)\\?\]' # Matches on a line that starts with '## [Version]' or '## \[Version\]'
    $changelogVersion = Get-Content $changelogPath | ForEach-Object {
        if ($_ -match $changelogVersionPattern) {
            $changelogVersion = $matches.Version
            break
        }
    }
}
Describe 'Module manifest' {

    Context 'Validation' {

        It 'Has a valid manifest' {
            $manifestData | Should -Not -BeNullOrEmpty
        }

        It 'Has a valid name in the manifest' {
            $manifestData.Name | Should -Be $Env:BHProjectName
        }

        It 'Has a valid root module' {
            $manifestData.RootModule | Should -Be "$($Env:BHProjectName).psm1"
        }

        It 'Has a valid version in the manifest' {
            $manifestData.Version -as [Version] | Should -Not -BeNullOrEmpty
        }

        It 'Has a valid description' {
            $manifestData.Description | Should -Not -BeNullOrEmpty
        }

        It 'Has a valid author' {
            $manifestData.Author | Should -Not -BeNullOrEmpty
        }

        It 'Has a valid guid' {
            { [guid]::Parse($manifestData.Guid) } | Should -Not -Throw
        }

        It 'Has a valid copyright' {
            $manifestData.CopyRight | Should -Not -BeNullOrEmpty
        }

        It 'Has a valid version in the changelog' {
            $changelogVersion | Should -Not -BeNullOrEmpty
            $changelogVersion -as [Version] | Should -Not -BeNullOrEmpty
        }

        It 'Changelog and manifest versions are the same' {
            $changelogVersion -as [Version] | Should -Be ( $manifestData.Version -as [Version] )
        }
    }
}

Describe 'Git tagging' -Skip {
    BeforeAll {
        $gitTagVersion = $null

        if ($git = Get-Command -Name 'git' -CommandType 'Application' -ErrorAction 'SilentlyContinue') {
            $thisCommit = & $git log --decorate --oneline HEAD~1..HEAD
            if ($thisCommit -match 'tag:\s*(\d+(?:\.\d+)*)') { $gitTagVersion = $matches[1] }
        }
    }

    It 'Is tagged with a valid version' {
        $gitTagVersion | Should -Not -BeNullOrEmpty
        $gitTagVersion -as [Version] | Should -Not -BeNullOrEmpty
    }

    It 'Matches manifest version' {
        $manifestData.Version -as [Version] | Should -Be ( $gitTagVersion -as [Version])
    }
}
