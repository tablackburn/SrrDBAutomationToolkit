# Upgrading to psake v5

## Contents

- Quick Compatibility Check
- Breaking Changes
- Step-by-Step Migration
- Speed Up Builds with Caching
- Structured Output for CI
- Testability APIs
- Before/After Examples

## Quick Compatibility Check

Most v4 build scripts work in v5 without changes. Check these three things:

1. **Build file name**: If using `default.ps1`, rename to `psakefile.ps1`
2. **Runner scripts**: If calling `psake.ps1` or `psake.cmd`, switch to `Import-Module psake; Invoke-psake`
3. **Framework**: If using `Framework '3.5'` or lower, update to `'4.0'` or higher

If none of these apply, your build script already works on v5.

## Breaking Changes

| What changed | v4 | v5 | Action needed |
|---|---|---|---|
| Min PowerShell | 3.0 | 5.1 | Upgrade PowerShell |
| Build file discovery | `default.ps1` fallback | `psakefile.ps1` only | Rename file |
| Runner scripts | `psake.ps1`, `psake.cmd` | Removed | Use `Invoke-psake` |
| .NET Framework | 1.0–4.8 | 4.0–4.8 only | Update `Framework` calls |
| `$framework` global | Set framework version | Removed | Use `Framework '4.7.2'` function |
| Output handlers | `psake-config.ps1` overrides | Removed | Use `-OutputFormat` parameter |
| Return value | Nothing (check `$psake.build_success`) | `PsakeBuildResult` object | Optional — `$psake.build_success` still works |

## Step-by-Step Migration

### 1. Add Version Declaration (optional but recommended)

```powershell
Version 5

Properties { ... }
Task Default -depends Build
```

This pins the build script to psake v5 and gives a clear error if someone runs it with v4.

### 2. Rename default.ps1

```powershell
# If your build file is named default.ps1:
Rename-Item default.ps1 psakefile.ps1
```

### 3. Update Runner Scripts

```powershell
# Before (v4)
& ./psake.ps1 Build

# After (v5)
Import-Module psake
Invoke-psake -taskList Build
```

### 4. Replace Output Handler Customization

```powershell
# Before: psake-config.ps1
$config.outputHandlers.writeOutput = { param($message, $type) ... }

# After: Use built-in output formats
Invoke-psake -OutputFormat GitHubActions   # CI annotations
Invoke-psake -OutputFormat JSON            # Machine-readable
Invoke-psake -Quiet                        # Suppress output, still returns result
```

To suppress colored output, set the `NO_COLOR` environment variable.

### 5. Update CI Scripts That Check Build Success

```powershell
# Before — still works, no change needed
Invoke-psake
if (!$psake.build_success) { exit 1 }

# After — cleaner with structured result
$result = Invoke-psake -Quiet
if (-not $result.Success) {
    Write-Error $result.ErrorMessage
    exit 1
}
```

## Speed Up Builds with Caching

The biggest performance win in v5 is file-based task caching. Tasks with `Inputs` and `Outputs` are skipped when their input files haven't changed.

### Adding Caching to Existing Tasks

Identify tasks that transform files (compile, transpile, copy) and add `Inputs`/`Outputs`:

```powershell
# Before: runs every time
Task Build -depends Clean {
    exec { dotnet build -c $Configuration }
}

# After: skipped when source hasn't changed
Task 'Build' @{
    DependsOn = 'Clean'
    Inputs    = 'src/**/*.cs', 'src/**/*.csproj'
    Outputs   = 'bin/**/*.dll'
    Action    = { exec { dotnet build -c $Configuration } }
}
```

psake computes a SHA256 hash of all input files plus the Action scriptblock text. On repeat runs, if the hash matches and outputs exist, the task prints "Skipped (cached)" and moves on.

### Good Candidates for Caching

| Task type | Inputs | Outputs |
|-----------|--------|---------|
| .NET build | `src/**/*.cs`, `*.csproj` | `bin/**/*.dll` |
| npm build | `src/**/*.ts`, `package-lock.json` | `dist/**/*` |
| SASS/CSS | `styles/**/*.scss` | `dist/**/*.css` |
| Docker build | `Dockerfile`, `src/**/*` | (skip — Docker has its own cache) |
| Tests | Don't cache — tests should always run | |
| Clean | Don't cache — always runs | |

### Dynamic File Lists

When glob patterns aren't enough, use scriptblocks:

```powershell
Task 'Build' @{
    Inputs = {
        Get-ChildItem src -Recurse -Include *.cs |
            Where-Object { $_.Name -notmatch '\.generated\.' }
    }
    Outputs = {
        Get-ChildItem bin -Recurse -Include *.dll -ErrorAction SilentlyContinue
    }
    Action = { exec { dotnet build } }
}
```

### Cache Management

```powershell
# Force full rebuild (single run)
Invoke-psake -NoCache

# Clear all cached state
Clear-PsakeCache

# Clear cache for one task
Clear-PsakeCache -TaskName 'Build'
```

Cache files live in `.psake/cache/` — add `.psake/` to your `.gitignore`.

### Verifying Cache Hits

The Build Time Report now shows a `Cached` column:

```
Build Time Report
----------------------------------------------------------------------
Name     Duration        Cached
----     --------        ------
Clean    00:00:00.012    False
Build    00:00:00.001    True     ← skipped, served from cache
Test     00:00:01.340    False
Total:   00:00:01.353
```

Or use `-OutputFormat JSON` and check the `Cached` property on each task result.

## Structured Output for CI

### PsakeBuildResult

`Invoke-psake` now returns a `PsakeBuildResult`:

```powershell
$result = Invoke-psake -Quiet

$result.Success          # $true / $false
$result.Duration         # [TimeSpan]
$result.BuildFile        # Path to build script
$result.ErrorMessage     # Error details if failed
$result.Tasks            # PsakeTaskResult[] array
```

Each task result contains:

```powershell
$result.Tasks[0].Name      # 'Build'
$result.Tasks[0].Status    # 'Executed', 'Skipped', 'Failed', 'Cached'
$result.Tasks[0].Duration  # [TimeSpan]
$result.Tasks[0].Cached    # $true / $false
```

### JSON Output

```powershell
# Pipe JSON to a file for CI artifacts
Invoke-psake -OutputFormat JSON > build-result.json
```

### GitHub Actions Annotations

```powershell
Invoke-psake -OutputFormat GitHubActions
```

Errors and warnings appear as inline annotations on the PR diff.

## Testability APIs

### Validate a Build Plan Without Running

```powershell
$plan = Get-PsakeBuildPlan -BuildFile './psakefile.ps1'

# Check structure
$plan.IsValid           # $true
$plan.ValidationErrors  # @() — empty if valid
$plan.ExecutionOrder    # @('Clean', 'Build', 'Test', 'Default')
$plan.TaskMap           # Hashtable of task name → task object

# Inspect dependencies
$plan.TaskMap['build'].DependsOn  # @('Clean')
```

This catches circular dependencies, missing tasks, and version mismatches at compile time — before any task runs.

### Test a Single Task in Isolation

```powershell
$result = Test-PsakeTask -TaskName 'Build' -Variables @{
    Configuration = 'Debug'
    OutputDir     = './test-output'
}
$result.Status    # 'Executed'
$result.Duration  # TimeSpan
```

Dependencies are NOT executed — only the named task's Action runs. This enables unit-testing individual tasks in Pester.

### Compile-Only Mode

```powershell
$plan = Invoke-psake -CompileOnly
# Same as Get-PsakeBuildPlan but through the Invoke-psake entry point
```

## Before/After Examples

### Full v4 → v5 Upgrade

**Before (v4):**

```powershell
Properties {
    $Configuration = 'Release'
    $BuildDir = './build'
}

Task Default -depends Test

Task Clean {
    if (Test-Path $BuildDir) { Remove-Item $BuildDir -Recurse -Force }
}

Task Build -depends Clean {
    exec { dotnet build -c $Configuration -o $BuildDir }
}

Task Test -depends Build {
    exec { dotnet test }
}
```

**After (v5 with caching and structured output):**

```powershell
Version 5

Properties @{
    Configuration = 'Release'
    BuildDir      = './build'
}

Task Default -depends Test

Task Clean {
    if (Test-Path $BuildDir) { Remove-Item $BuildDir -Recurse -Force }
}

Task 'Build' @{
    DependsOn = 'Clean'
    Inputs    = 'src/**/*.cs', 'src/**/*.csproj'
    Outputs   = 'bin/**/*.dll'
    Action    = { exec { dotnet build -c $Configuration -o $BuildDir } }
}

Task Test -depends Build {
    exec { dotnet test }
}
```

The second version skips the Build task entirely when source files haven't changed — in a typical edit-test loop this cuts build time significantly.
