# Complete PowerShellBuild Example

## Project Structure

```
MyModule/
├── src/
│   ├── MyModule.psd1
│   ├── MyModule.psm1
│   ├── Private/
│   │   └── HelperFunction.ps1
│   └── Public/
│       └── Get-Something.ps1
├── tests/
│   └── MyModule.Tests.ps1
├── docs/
├── build.ps1
├── psakeFile.ps1
└── requirements.psd1
```

## build.ps1

```powershell
[cmdletbinding(DefaultParameterSetName = 'Task')]
param(
    [parameter(ParameterSetName = 'Task', position = 0)]
    [string[]]$Task = 'default',

    [switch]$Bootstrap,

    [parameter(ParameterSetName = 'Help')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Bootstrap.IsPresent) {
    Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    if (-not (Get-Module -Name PSDepend -ListAvailable)) {
        Install-Module -Name PSDepend -Repository PSGallery -Scope CurrentUser
    }
    Import-Module -Name PSDepend -Verbose:$false
    Invoke-PSDepend -Path './requirements.psd1' -Install -Import -Force -WarningAction SilentlyContinue
}

$psakeFile = './psakeFile.ps1'
if ($PSCmdlet.ParameterSetName -eq 'Help') {
    Get-PSakeScriptTasks -buildFile $psakeFile | Format-Table -Property Name, Description
} else {
    Set-BuildEnvironment -Force
    Invoke-psake -buildFile $psakeFile -taskList $Task -Verbose:$VerbosePreference
    exit ([int](-not $psake.build_success))
}
```

## requirements.psd1

```powershell
@{
    PSDependOptions  = @{ Target = 'CurrentUser' }
    psake            = '4.9.0'
    PowerShellBuild  = 'latest'
    Pester           = @{
        MinimumVersion = '5.6.1'
        Parameters     = @{ SkipPublisherCheck = $true }
    }
    PSScriptAnalyzer = '1.24.0'
    platyPS          = '0.14.2'
}
```

## psakeFile.ps1 (full)

```powershell
properties {
    $PSBPreference.Build.CompileModule             = $true
    $PSBPreference.Build.CompileDirectories        = @('Enum', 'Classes', 'Private', 'Public')
    $PSBPreference.Test.ScriptAnalysis.Enabled     = $true
    $PSBPreference.Test.CodeCoverage.Enabled       = $true
    $PSBPreference.Test.CodeCoverage.Threshold     = 0.80
    $PSBPreference.Publish.PSRepositoryApiKey      = $env:PSGALLERY_API_KEY
}

task default -depends Test

task Clean   -FromModule PowerShellBuild
task Build   -FromModule PowerShellBuild
task Analyze -FromModule PowerShellBuild
task Pester  -FromModule PowerShellBuild
task Test    -FromModule PowerShellBuild
task Publish -FromModule PowerShellBuild
```
