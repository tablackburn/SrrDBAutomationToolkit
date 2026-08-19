---
name: psake
description: This skill should be used when the user asks to "create a psakefile", "set up a psake build", "add psake caching", "migrate to psake v5", "troubleshoot a psake build", or mentions psake, psakefile.ps1, Invoke-psake, build task dependencies, exec blocks, PsakeBuildResult, Get-PsakeBuildPlan, or PowerShell build automation for .NET, Node.js, or Docker projects. Also triggers on requests to set up CI/CD pipelines (GitHub Actions, Azure Pipelines, GitLab CI) using psake.
---

# psake Build Automation

psake is a PowerShell build automation tool using a DSL for task-based builds with dependencies. psake v5 introduces a two-phase compile/run model, declarative syntax, file-based caching, and structured output.

## Decision Tree

**What kind of build are you creating?**

1. **PowerShell module** → Use PowerShellBuild module (see references/powershell-modules.md)
2. **.NET/Node.js/Docker** → See references/build-types.md
3. **Simple custom build** → Continue below for core psake patterns

**Build complexity?**

- **Simple** (< 5 tasks, single project) → Use patterns in this file
- **Complex** (CI/CD, multiple environments, dynamic tasks) → See references/advanced.md

## Quick Start

```powershell
# Install
Install-Module -Name psake -Scope CurrentUser -Force

# Run — interactive (prints formatted output to console)
Invoke-psake                              # Run 'Default' task
Invoke-psake -taskList Build, Test        # Run specific tasks
Invoke-psake -docs                        # Show task documentation

# Run — programmatic: LLM agents, CI scripts, build.ps1 wrappers
# -Quiet suppresses all console output and returns a PsakeBuildResult object.
# Always use this form when you need to check success or read task results.
$result = Invoke-psake -taskList Build, Test -Quiet
$result.Success        # $true / $false — check this, don't parse console text
$result.ErrorMessage   # populated when Success is $false
$result.Tasks          # PsakeTaskResult[] — Name, Status, Duration, Cached
```

## Minimal psakefile.ps1

```powershell
Version 5

Properties {
    $BuildDir = Join-Path $PSScriptRoot 'build'
}

Task Default -depends Build

Task Clean {
    if (Test-Path $BuildDir) { Remove-Item $BuildDir -Recurse -Force }
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}

Task Build -depends Clean {
    exec { dotnet build -o $BuildDir }
}

Task Test -depends Build {
    exec { dotnet test }
}
```

## Programmatic Invocation

**Always use `-Quiet` when invoking psake from a script, CI step, or LLM agent.** Without it, psake streams formatted text to the console — noisy and unparseable. With it, psake returns a `PsakeBuildResult` object and produces no console output.

```powershell
$result = Invoke-psake -buildFile ./psakefile.ps1 -taskList Build, Test -Quiet

if (-not $result.Success) {
    Write-Error $result.ErrorMessage
    exit 1
}

# Inspect task-level results
$result.Tasks | ForEach-Object {
    "$($_.Name): $($_.Status) ($($_.Duration.TotalSeconds)s)"
}
```

### build.ps1 Entry-Point Template

Projects often have a thin `build.ps1` wrapper that bootstraps dependencies and delegates to psake. Generate it with the `-Quiet` pattern so any caller — human or LLM — gets structured results:

```powershell
# build.ps1
#
# Usage (interactive):   ./build.ps1                 # default task
#                        ./build.ps1 Build, Test     # specific tasks
#                        ./build.ps1 -Bootstrap      # install deps first
#
# Usage (programmatic):  Invoke-psake -buildFile ./psakefile.ps1 -Quiet
#   -Quiet returns a PsakeBuildResult (.Success, .Tasks, .ErrorMessage).
#   Use that form directly in CI steps and LLM agents — skip this script.

[CmdletBinding()]
param(
    [ArgumentCompleter({
        param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
        try {
            Get-PSakeScriptTasks -BuildFile (Join-Path $PSScriptRoot 'psakefile.ps1') -ErrorAction Stop |
                Where-Object { $_.Name -like "$WordToComplete*" } |
                Select-Object -ExpandProperty Name
        } catch { @() }
    })]
    [string[]]$Task = 'Default',

    [switch]$Bootstrap
)

$ErrorActionPreference = 'Stop'

if ($Bootstrap) {
    if (-not (Get-Module -ListAvailable -Name PSDepend)) {
        Install-Module -Name PSDepend -Scope CurrentUser -Force -AllowClobber
    }
    $psDependArgs = @{
        Path          = $PSScriptRoot
        Recurse       = $false
        Install       = $true
        Import        = $true
        Force         = $true
    }
    Invoke-PSDepend @psDependArgs
} else {
    # Try importing cached modules first — avoids file-lock contention when CI
    # jobs share a module cache and one job is mid-install.
    $psDependArgs = @{
        Path          = $PSScriptRoot
        Recurse       = $false
        Import        = $true
        Force         = $true
        WarningAction = 'SilentlyContinue'
    }
    $imported = $false
    try { Invoke-PSDepend @psDependArgs; $imported = $true } catch {}

    if (-not $imported) {
        $psDependArgs['Install'] = $true
        try {
            Invoke-PSDepend @psDependArgs
        } catch {
            throw "Dependency install failed. If modules are locked, restart the build environment or re-run with -Bootstrap."
        }
    }
}

$psakeArgs = @{
    buildFile = Join-Path $PSScriptRoot 'psakefile.ps1'
    taskList  = $Task
    Quiet     = $true
}
$result = Invoke-psake @psakeArgs

if (-not $result.Success) {
    Write-Error $result.ErrorMessage
    exit 1
}
```

> **For LLM agents:** skip `build.ps1` entirely. Call `Invoke-psake -Quiet` directly and inspect the returned `PsakeBuildResult` — you get structured data without spawning a child process or parsing output.

## Core Commands

### Task

Two equivalent syntaxes — use whichever reads better for your build:

```powershell
# Classic syntax (works in v4 and v5)
Task Build -depends Clean -description "Compile project" {
    exec { dotnet build }
}

# Declarative syntax (v5 — hashtable with validated keys)
Task 'Build' @{
    DependsOn   = 'Clean'
    Description = 'Compile project'
    Action      = { exec { dotnet build } }
}
```

The declarative syntax validates keys at parse time — typos like `DependOn` throw immediately. Valid keys: `Action`, `DependsOn`, `Inputs`, `Outputs`, `PreAction`, `PostAction`, `PreCondition`, `PostCondition`, `ContinueOnError`, `Description`, `Alias`, `RequiredVariables`.

#### Task with Caching

Tasks with `Inputs` and `Outputs` are content-addressed cached in `.psake/cache/`. If input file hashes haven't changed and output files exist, the task is skipped.

```powershell
Task 'Build' @{
    DependsOn = 'Clean'
    Inputs    = 'src/**/*.cs', 'src/**/*.csproj'
    Outputs   = 'bin/**/*.dll'
    Action    = { exec { dotnet build -c $Configuration } }
}
```

Inputs/Outputs also accept scriptblocks for dynamic file resolution:

```powershell
Task 'Build' @{
    Inputs  = { Get-ChildItem src -Recurse -Include *.cs }
    Outputs = { Get-ChildItem bin -Recurse -Include *.dll -ErrorAction SilentlyContinue }
    Action  = { exec { dotnet build } }
}
```

Use `Clear-PsakeCache` to force a full rebuild, or `Invoke-psake -NoCache` for a single run.

#### Conditional Execution

```powershell
Task Deploy -precondition { $env:CI -eq 'true' } -description "Deploy to prod" {
    exec { ./deploy.ps1 }
}
```

### Properties

Variables available to all tasks. Can be overridden via `-properties` parameter.

```powershell
# Scriptblock syntax
Properties {
    $Configuration = 'Release'
    $Version = '1.0.0'
}

# Hashtable syntax (v5)
Properties @{
    Configuration = 'Release'
    Version       = '1.0.0'
}
```

Override: `Invoke-psake -properties @{ Configuration = 'Debug' }`

### Version

Pin your build script to a psake major version. The compile phase rejects version mismatches.

```powershell
Version 5
```

### exec

Runs external commands, fails build on non-zero exit:

```powershell
exec { dotnet build }                                    # Basic
exec { npm install } "npm install failed"                # Custom error
exec { nuget restore } -maxRetries 3                     # Retry flaky ops
exec { npm test } -workingDirectory './frontend'         # Different directory
exec { ./slow-build.ps1 } -TimeoutSeconds 600            # Timeout (v5)
```

### Assert

```powershell
Assert (Test-Path $SrcDir) "Source directory not found"
Assert (-not [string]::IsNullOrEmpty($ApiKey)) "API key required"
```

### Include

```powershell
Include "./shared/common-tasks.ps1"
```

### FormatTaskName

```powershell
FormatTaskName "▶ {0}"
# Or with scriptblock:
FormatTaskName { param($taskName) Write-Host "[$taskName]" -ForegroundColor Cyan }
```

### TaskSetup / TaskTearDown

```powershell
TaskSetup { Write-Host "Starting: $($psake.context.currentTaskName)" }
TaskTearDown { Write-Host "Finished: $($psake.context.currentTaskName)" }
```

## Structured Output

`Invoke-psake` returns a `PsakeBuildResult` object:

```powershell
$result = Invoke-psake -Quiet
$result.Success          # $true / $false
$result.Duration         # TimeSpan
$result.Tasks            # PsakeTaskResult[] with Name, Status, Duration, Cached
$result.ErrorMessage     # Error details if failed
```

The `$psake.build_success` variable is still set after each build for backward compatibility.

For CI pipelines, use JSON output:

```powershell
Invoke-psake -OutputFormat JSON
```

## Invoke-psake Parameters

| Parameter | Description |
|-----------|-------------|
| `-buildFile` | Path to build script (default: psakefile.ps1) |
| `-taskList` | Tasks to execute (default: 'Default') |
| `-parameters` | Hashtable passed to build script (set before Properties) |
| `-properties` | Hashtable to override Properties block (set after Properties) |
| `-docs` | Display task documentation |
| `-nologo` | Suppress banner |
| `-OutputFormat` | `Default`, `JSON`, or `GitHubActions` (v5) |
| `-NoCache` | Bypass task caching for this run (v5) |
| `-CompileOnly` | Return build plan without executing (v5) |
| `-Quiet` | Suppress console output; still returns PsakeBuildResult (v5) |

## Testability APIs

### Inspect the Build Plan

```powershell
$plan = Get-PsakeBuildPlan -BuildFile './psakefile.ps1'
$plan.ExecutionOrder    # ['Clean', 'Build', 'Test', 'Default']
$plan.TaskMap['build'].DependsOn  # ['Clean']
$plan.IsValid           # $true
$plan.ValidationErrors  # @()
```

The plan can also be piped into `Invoke-psake`:

```powershell
Get-PsakeBuildPlan | Invoke-psake
```

### Test a Task in Isolation

```powershell
$result = Test-PsakeTask -BuildFile './psakefile.ps1' -TaskName 'Build' -Variables @{
    Configuration = 'Debug'
}
$result.Status    # 'Executed'
$result.Duration  # TimeSpan
```

## Common Patterns

### Environment-Specific

```powershell
Properties {
    $Env = if ($env:ENVIRONMENT) { $env:ENVIRONMENT } else { 'Development' }
}

Task Deploy {
    switch ($Env) {
        'Production' { exec { ./deploy-prod.ps1 } }
        default      { Write-Host "Skipping deploy for $Env" }
    }
}
```

### Multi-Project

```powershell
Task BuildAll -depends BuildBackend, BuildFrontend

Task BuildBackend {
    Push-Location ./backend
    try { exec { dotnet build } }
    finally { Pop-Location }
}

Task BuildFrontend {
    Push-Location ./frontend
    try { exec { npm run build } }
    finally { Pop-Location }
}
```

### Variable Scoping Between Tasks

Tasks don't share local variables. Use `$script:` scope to pass data between dependent tasks:

```powershell
Task GetFiles {
    $script:Files = Get-ChildItem -Path $SrcDir -Filter *.ps1
}

Task ProcessFiles -depends GetFiles {
    foreach ($file in $script:Files) {
        # Process each file
    }
}
```

> **Note:** psake tasks don't have return values. `$script:` scoped variables are the recommended approach for task-to-task data sharing.

## Validating a psakefile

### Using Get-PsakeBuildPlan (recommended)

The compile phase catches circular dependencies, missing tasks, and version mismatches before any task runs:

```powershell
$plan = Get-PsakeBuildPlan -BuildFile './psakefile.ps1'
if (-not $plan.IsValid) {
    $plan.ValidationErrors | ForEach-Object { Write-Error $_ }
} else {
    Write-Host "✓ Build plan valid — execution order: $($plan.ExecutionOrder -join ' → ')"
}
```

### Syntax Check

```powershell
$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path 'psakefile.ps1'), [ref]$null, [ref]$errors
)
if ($errors) { $errors | ForEach-Object { Write-Error $_.ToString() } }
else { Write-Host "✓ Syntax valid" -ForegroundColor Green }
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Build fails but CI shows success | Use `exec { }` for all external commands |
| Cross-platform path issues | Use `Join-Path` instead of `\` or `/` |
| Module not found in CI | `Install-Module -Name psake -Scope CurrentUser -Force` |
| Properties not overriding | Use `-properties` (not `-parameters`) to override Properties block |
| Variable undefined in dependent task | Use `$script:VarName` to share data between tasks |
| Circular dependency error | Check `Get-PsakeBuildPlan` output for `ValidationErrors` |
| Task skipped unexpectedly | May be cached — run with `-NoCache` or `Clear-PsakeCache` |
| `default.ps1` not found | v5 removed `default.ps1` fallback — rename to `psakefile.ps1` |

## References

- **references/upgrading-to-v5.md** - Migration guide, caching for faster builds, structured output, testability APIs
- **references/powershell-modules.md** - PowerShellBuild module for PS module development
- **references/build-types.md** - .NET, Node.js, Docker build patterns
- **references/advanced.md** - Dynamic tasks, CI/CD integration, $psake reference
