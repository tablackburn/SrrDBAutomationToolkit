# Advanced psake Patterns

## Contents

- Dynamic Task Generation (from package.json, directories, config files)
- CI/CD Integration (GitHub Actions, Azure Pipelines, GitLab CI)
- Nested Builds
- Error Handling Patterns
- $psake Variable Reference

## Dynamic Task Generation

Generate tasks from external sources at runtime.

### From package.json Scripts

```powershell
# Read package.json and create tasks for each npm script
$packageJson = Get-Content './package.json' | ConvertFrom-Json
$npmScripts = $packageJson.scripts.PSObject.Properties

foreach ($script in $npmScripts) {
    $taskName = "npm:$($script.Name)"
    $scriptName = $script.Name
    
    Task $taskName -description "Run npm script: $scriptName" {
        exec { npm run $scriptName }
    }.GetNewClosure()
}

Task NpmAll -depends ($npmScripts | ForEach-Object { "npm:$($_.Name)" })
```

### From Directory Contents

```powershell
# Create a task for each project in a monorepo
$projects = Get-ChildItem './packages' -Directory

foreach ($project in $projects) {
    $projectName = $project.Name
    $projectPath = $project.FullName
    
    Task "build:$projectName" -description "Build $projectName" {
        Push-Location $projectPath
        try { exec { npm run build } }
        finally { Pop-Location }
    }.GetNewClosure()
}

Task BuildAll -depends ($projects | ForEach-Object { "build:$($_.Name)" })
```

### From Configuration File

```powershell
# build-config.psd1
@{
    Projects = @(
        @{ Name = 'Api'; Path = './src/Api'; Type = 'dotnet' }
        @{ Name = 'Web'; Path = './src/Web'; Type = 'npm' }
    )
}
```

```powershell
$config = Import-PowerShellDataFile './build-config.psd1'

foreach ($project in $config.Projects) {
    $name = $project.Name
    $path = $project.Path
    $type = $project.Type
    
    Task "build:$name" {
        Push-Location $path
        try {
            switch ($type) {
                'dotnet' { exec { dotnet build } }
                'npm'    { exec { npm run build } }
            }
        }
        finally { Pop-Location }
    }.GetNewClosure()
}
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Build

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Cache PowerShell modules
        uses: actions/cache@v4
        with:
          path: |
            ~/.local/share/powershell/Modules
            ~/Documents/PowerShell/Modules
          key: ${{ runner.os }}-psake
      
      - name: Install psake
        shell: pwsh
        run: |
          Set-PSRepository PSGallery -InstallationPolicy Trusted
          Install-Module psake -Scope CurrentUser -Force
      
      - name: Build and Test
        shell: pwsh
        run: Invoke-psake -taskList Build, Test -OutputFormat GitHubActions
      
      - name: Publish
        if: github.ref == 'refs/heads/main' && matrix.os == 'ubuntu-latest'
        shell: pwsh
        run: Invoke-psake -taskList Publish
        env:
          NUGET_API_KEY: ${{ secrets.NUGET_API_KEY }}
```

`-OutputFormat GitHubActions` emits `::error::`, `::warning::`, and `::debug::` annotations that show inline in PR diffs.

### Azure Pipelines

```yaml
trigger:
  branches:
    include: [main]

pool:
  vmImage: 'windows-latest'

variables:
  - group: BuildSecrets

stages:
  - stage: Build
    jobs:
      - job: BuildJob
        steps:
          - pwsh: |
              Install-Module psake -Scope CurrentUser -Force
              $psakeArgs = @{
                taskList   = 'Build', 'Test'
                parameters = @{ BuildNumber = '$(Build.BuildNumber)' }
                Quiet      = $true
              }
              $result = Invoke-psake @psakeArgs
              if (-not $result.Success) { exit 1 }
            displayName: 'Build and Test'
          
          - publish: $(System.DefaultWorkingDirectory)/build
            artifact: BuildOutput

  - stage: Deploy
    condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')
    jobs:
      - deployment: DeployJob
        environment: production
        strategy:
          runOnce:
            deploy:
              steps:
                - pwsh: Invoke-psake -taskList Publish
                  env:
                    NUGET_API_KEY: $(NuGetApiKey)
```

### GitLab CI/CD

```yaml
image: mcr.microsoft.com/powershell:latest

stages:
  - build
  - test
  - deploy

variables:
  PSMODULE_CACHE: "$CI_PROJECT_DIR/.psmodules"

cache:
  key: psake-modules
  paths:
    - .psmodules/

before_script:
  - pwsh -c "Install-Module psake -Scope CurrentUser -Force"

build:
  stage: build
  script:
    - pwsh -c "Invoke-psake -taskList Build"
  artifacts:
    paths:
      - build/

test:
  stage: test
  script:
    - pwsh -c "Invoke-psake -taskList Test"
  artifacts:
    reports:
      junit: TestResults/*.xml

deploy:
  stage: deploy
  script:
    - pwsh -c "Invoke-psake -taskList Publish"
  environment:
    name: production
  only:
    - main
  when: manual
```

## Nested Builds

Call psake from within a task:

```powershell
Task BuildSubProject {
    $result = Invoke-psake -buildFile './subproject/psakefile.ps1' -taskList Build -Quiet
    
    if (-not $result.Success) {
        throw "Subproject build failed: $($result.ErrorMessage)"
    }
}
```

## Error Handling Patterns

### Continue on Error

```powershell
Task OptionalCleanup -continueOnError {
    Remove-Item './temp' -Recurse -Force -ErrorAction Stop
}
```

### Custom Error Recovery

```powershell
Task DeployWithRollback -depends Build {
    $deployed = $false
    try {
        exec { ./deploy.ps1 }
        $deployed = $true
    } catch {
        if ($deployed) {
            Write-Host "Deployment failed, rolling back..."
            exec { ./rollback.ps1 }
        }
        throw
    }
}
```

### Retry with Backoff

```powershell
Task FlakyOperation {
    $maxRetries = 3
    $retryDelay = 5
    
    for ($i = 1; $i -le $maxRetries; $i++) {
        try {
            exec { ./flaky-script.ps1 }
            break
        } catch {
            if ($i -eq $maxRetries) { throw }
            Write-Host "Attempt $i failed, retrying in ${retryDelay}s..."
            Start-Sleep -Seconds $retryDelay
            $retryDelay *= 2
        }
    }
}
```

## $psake Variable Reference

Access build context:

```powershell
$psake.build_script_file      # Full path to current build script
$psake.build_script_dir       # Directory of build script
$psake.version                # psake version
$psake.context                # Current execution context
$psake.context.currentTaskName # Name of executing task
$psake.build_success          # $true if build succeeded (check after Invoke-psake)
```
