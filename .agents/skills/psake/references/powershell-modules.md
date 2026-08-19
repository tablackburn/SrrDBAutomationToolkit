# PowerShell Module Builds

## Contents

- Quick Start
- Available Tasks (Primary, Secondary)
- Configuration ($PSBPreference)
- Modifying Task Dependencies
- Complete Example (project structure, build.ps1, requirements.psd1, psakeFile.ps1)
- CI/CD Integration
- Troubleshooting

For PowerShell module development, use **PowerShellBuild** - a collection of pre-built psake tasks.

## Quick Start

```powershell
# Install
Install-Module -Name PowerShellBuild -Scope CurrentUser -Force
Install-Module -Name psake -Scope CurrentUser -Force
```

### Minimal psakeFile.ps1

```powershell
properties {
    $PSBPreference.Test.ScriptAnalysis.Enabled = $true
    $PSBPreference.Test.CodeCoverage.Enabled = $false
}

task default -depends Test

task Test    -FromModule PowerShellBuild
task Publish -FromModule PowerShellBuild
```

This single file gives you: Init → Clean → StageFiles → BuildHelp → Build → Analyze → Pester → Test → Publish

## Available Tasks

### Primary Tasks

| Task | Dependencies | Description |
|------|--------------|-------------|
| Init | none | Initialize psake and task variables |
| Clean | Init | Clean output directory |
| Build | StageFiles, BuildHelp | Build module in output directory |
| Analyze | Build | Run PSScriptAnalyzer |
| Pester | Build | Run Pester tests |
| Test | Analyze, Pester | Run all tests |
| Publish | Test | Publish to PowerShell repository |

### Secondary Tasks

| Task | Description |
|------|-------------|
| StageFiles | Copy module files to output |
| GenerateMarkdown | Build PlatyPS markdown help |
| GenerateMAML | Build MAML help from markdown |
| BuildHelp | Build all help files |

## Configuration ($PSBPreference)

Override in your psakeFile.ps1 `properties` block:

### Build Settings

```powershell
$PSBPreference.General.ModuleName = 'MyModule'
$PSBPreference.General.SrcRootDir = './src'
$PSBPreference.Build.OutDir = './Output'
$PSBPreference.Build.CompileModule = $true          # Combine into single PSM1
$PSBPreference.Build.CompileDirectories = @('Enum', 'Classes', 'Private', 'Public')
$PSBPreference.Build.CopyDirectories = @('Data')    # Copy as-is
```

### Test Settings

```powershell
$PSBPreference.Test.Enabled = $true
$PSBPreference.Test.RootDir = './tests'
$PSBPreference.Test.ScriptAnalysis.Enabled = $true
$PSBPreference.Test.ScriptAnalysis.FailBuildOnSeverityLevel = 'Error'
$PSBPreference.Test.CodeCoverage.Enabled = $true
$PSBPreference.Test.CodeCoverage.Threshold = 0.75
```

### Publish Settings

```powershell
$PSBPreference.Publish.PSRepository = 'PSGallery'
$PSBPreference.Publish.PSRepositoryApiKey = $env:PSGALLERY_API_KEY
```

## Modifying Task Dependencies

Set before referencing PowerShellBuild tasks:

```powershell
# Skip help generation
$PSBBuildDependency = 'StageFiles'

# Skip analysis in Test
$PSBTestDependency = 'Pester'

# Publish without testing (not recommended)
$PSBPublishDependency = 'Build'
```

## Complete Example

### Project Structure

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

### build.ps1 (Entry Point)

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

### requirements.psd1

```powershell
@{
    psake = '5.0.0'
    PowerShellBuild = '0.7.0'
    Pester = '5.6.1'
    PSScriptAnalyzer = '1.24.0'
    PlatyPS = '0.14.2'
}
```

### psakeFile.ps1

```powershell
properties {
    # Override defaults
    $PSBPreference.Build.CompileModule = $true
    $PSBPreference.Test.CodeCoverage.Enabled = $true
    $PSBPreference.Test.CodeCoverage.Threshold = 0.80
}

task default -depends Test

task Test -FromModule PowerShellBuild
task Build -FromModule PowerShellBuild
task Publish -FromModule PowerShellBuild
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Build

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build and Test
        shell: pwsh
        run: ./build.ps1 -Task Test

      - name: Publish
        if: github.ref == 'refs/heads/main'
        shell: pwsh
        run: ./build.ps1 -Task Publish
        env:
          PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Task 'Build' not found" | Ensure psake ≥ 4.8.0 for `-FromModule` support |
| BuildHelp fails | Install PlatyPS: `Install-Module PlatyPS` |
| Tests not running | Check `$PSBPreference.Test.RootDir` path |
| ScriptAnalyzer fails | Create `ScriptAnalyzerSettings.psd1` or disable |
