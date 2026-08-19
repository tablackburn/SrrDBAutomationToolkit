---
name: powershellbuild
description: This skill should be used when the user asks to "set up PowerShellBuild", "create a psakeFile with -FromModule", "configure PSBPreference", "publish a PowerShell module to PSGallery", "set up Pester tests for a module", or mentions PowerShellBuild, PSBPreference, -FromModule PowerShellBuild, PowerShellBuild.IB.Tasks, PSScriptAnalyzer integration, PlatyPS help generation, code coverage thresholds, or PowerShell module build/test/publish pipelines.
---

# PowerShellBuild

PowerShellBuild provides standardized build, test, and publish tasks for PowerShell modules. It works with both **psake** (≥ 4.8.0) and **Invoke-Build** (≥ 5.8.1).

## Decision Tree

**Which task runner are you using?**
- **psake** → use `task <Name> -FromModule PowerShellBuild` pattern
- **Invoke-Build** → use `. PowerShellBuild.IB.Tasks` pattern
- **Not sure / starting fresh** → default to psake (simpler syntax)

**What do you need?**
- Set up a new module project → See `references/complete-example.md`
- Override build behavior → [Configuration ($PSBPreference)](#configuration-psbpreference)
- Customize task dependencies → [Modifying Task Dependencies](#modifying-task-dependencies)
- CI/CD setup → See `references/ci-cd.md`

## Quick Start

```powershell
Install-Module -Name PowerShellBuild -Repository PSGallery -Scope CurrentUser
Install-Module -Name psake -MinimumVersion 4.8.0 -Repository PSGallery -Scope CurrentUser
```

### Minimal psakeFile.ps1

> **Do NOT `Import-Module PowerShellBuild` in psakeFile.ps1** — `-FromModule` loads the module automatically when psake parses the task definitions.

```powershell
properties {
    $PSBPreference.Test.ScriptAnalysis.Enabled = $true
    $PSBPreference.Test.CodeCoverage.Enabled   = $false
}

task default -depends Test

task Test    -FromModule PowerShellBuild
task Publish -FromModule PowerShellBuild
```

This gives you: `Init → Clean → StageFiles → BuildHelp → Build → Analyze → Pester → Test → Publish`

## Project Structure

```
MyModule/
├── build.ps1              # Entry point
├── psakeFile.ps1          # Build tasks (psake)
├── .build.ps1             # Build tasks (Invoke-Build)
├── requirements.psd1      # Dependencies
├── MyModule/              # Source directory
│   ├── MyModule.psd1      # Module manifest
│   ├── MyModule.psm1      # Module root
│   ├── Public/            # Exported functions
│   └── Private/           # Internal functions
├── tests/
│   └── MyModule.Tests.ps1
└── Output/                # Build output (auto-generated)
```

## Available Tasks

### Primary Tasks

| Task    | Depends On          | Description                        |
|---------|---------------------|------------------------------------|
| Init    | —                   | Initialize build environment       |
| Clean   | Init                | Remove output directory            |
| Build   | StageFiles, BuildHelp | Compile module to output          |
| Analyze | Build               | Run PSScriptAnalyzer               |
| Pester  | Build               | Run Pester tests                   |
| Test    | Analyze, Pester     | Run all quality checks             |
| Publish | Test                | Publish to PowerShell Gallery      |

### Secondary Tasks

| Task               | Description                          |
|--------------------|--------------------------------------|
| StageFiles         | Copy source files to output          |
| GenerateMarkdown   | Generate PlatyPS markdown help       |
| GenerateMAML       | Convert markdown to MAML help        |
| BuildHelp          | Run all help generation              |

## Configuration ($PSBPreference)

Set these in your `properties` block before referencing PowerShellBuild tasks.

### Build

```powershell
$PSBPreference.General.ModuleName              = 'MyModule'       # auto-detected from manifest
$PSBPreference.General.SrcRootDir              = './MyModule'     # default: project root
$PSBPreference.Build.OutDir                    = './Output'
$PSBPreference.Build.CompileModule             = $true            # merge into single PSM1
$PSBPreference.Build.CompileDirectories        = @('Enum', 'Classes', 'Private', 'Public')
$PSBPreference.Build.CopyDirectories           = @('Data')        # copy as-is (no compile)
$PSBPreference.Build.Exclude                   = @('*.Tests.ps1')
```

### Test

```powershell
$PSBPreference.Test.Enabled                                = $true
$PSBPreference.Test.RootDir                               = './tests'
$PSBPreference.Test.OutputFile                            = 'TestResults.xml'
$PSBPreference.Test.OutputFormat                          = 'NUnitXml'
$PSBPreference.Test.ScriptAnalysis.Enabled                = $true
$PSBPreference.Test.ScriptAnalysis.FailBuildOnSeverityLevel = 'Error'
$PSBPreference.Test.CodeCoverage.Enabled                  = $true
$PSBPreference.Test.CodeCoverage.Threshold                = 0.75   # 0.0–1.0
```

### Help & Docs

```powershell
$PSBPreference.Help.DefaultLocale             = 'en-US'
$PSBPreference.Help.ConvertReadMeToAboutHelp  = $false
$PSBPreference.Docs.RootDir                   = './docs'
```

### Publish

```powershell
$PSBPreference.Publish.PSRepository        = 'PSGallery'
$PSBPreference.Publish.PSRepositoryApiKey  = $env:PSGALLERY_API_KEY
```

## Modifying Task Dependencies

Set these variables **before** the `-FromModule` references take effect:

```powershell
$PSBBuildDependency   = 'StageFiles'  # skip help generation
$PSBTestDependency    = 'Pester'      # skip analysis
$PSBPublishDependency = 'Build'       # publish without tests (not recommended)
```

## Invoke-Build Alternative

```powershell
. PowerShellBuild.IB.Tasks

$PSBPreference.Build.CompileModule         = $true
$PSBPreference.Test.CodeCoverage.Enabled   = $true
$PSBPreference.Test.CodeCoverage.Threshold = 0.75

task . Build
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Task 'Build' not found" | Ensure psake ≥ 4.8.0 for `-FromModule` support |
| Module not found | Run `./build.ps1 -Bootstrap` first |
| BuildHelp fails | Install PlatyPS: `Install-Module platyPS` |
| Tests not found | Check `$PSBPreference.Test.RootDir` matches your `tests/` path |
| ScriptAnalyzer fails build | Fix violations or set `FailBuildOnSeverityLevel = 'Warning'` |
| Code coverage below threshold | Raise `CodeCoverage.Threshold` or add tests |
| Publish fails | Verify `PSGALLERY_API_KEY` env var is set |

## References

- **`references/complete-example.md`** - Full project scaffold: build.ps1, requirements.psd1, psakeFile.ps1 with all tasks
- **`references/ci-cd.md`** - GitHub Actions workflow for test and publish pipelines
