# Build Type Patterns

## Contents

- .NET Projects (Modern SDK-style, Legacy .NET Framework)
- Node.js Projects (npm, TypeScript)
- Docker Builds (Basic, Compose)
- Multi-Technology Stack

## .NET Projects

### Modern .NET (SDK-style)

```powershell
Version 5

Properties @{
    SrcDir        = Join-Path $PSScriptRoot 'src'
    BuildDir      = Join-Path $PSScriptRoot 'build'
    Configuration = 'Release'
    Version       = '1.0.0'
}

Task Default -depends Test

Task Clean {
    if (Test-Path $BuildDir) { Remove-Item $BuildDir -Recurse -Force }
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}

Task Restore {
    exec { dotnet restore $SrcDir }
}

Task 'Build' @{
    DependsOn = 'Clean', 'Restore'
    Inputs    = 'src/**/*.cs', 'src/**/*.csproj'
    Outputs   = 'build/**/*.dll'
    Action    = { exec { dotnet build $SrcDir -c $Configuration -o $BuildDir --no-restore /p:Version=$Version } }
}

Task Test -depends Build {
    exec { 
        dotnet test $SrcDir -c $Configuration --no-build `
            --logger "trx;LogFileName=results.trx" `
            --results-directory "$BuildDir/TestResults"
    }
}

Task Pack -depends Test {
    exec { dotnet pack $SrcDir -c $Configuration -o $BuildDir --no-build /p:Version=$Version }
}

Task Publish -depends Pack {
    $apiKey = $env:NUGET_API_KEY
    Assert (-not [string]::IsNullOrEmpty($apiKey)) "NUGET_API_KEY required"
    
    Get-ChildItem "$BuildDir/*.nupkg" | ForEach-Object {
        exec { dotnet nuget push $_.FullName --api-key $apiKey --source nuget.org }
    }
}
```

### Legacy .NET Framework (MSBuild)

```powershell
Framework "4.7.2"

Properties {
    $Solution = Join-Path $PSScriptRoot 'MySolution.sln'
    $BuildDir = Join-Path $PSScriptRoot 'build'
}

Task Default -depends Build

Task Clean {
    exec { msbuild $Solution /t:Clean /p:Configuration=Release /v:minimal }
}

Task Build -depends Clean {
    exec { msbuild $Solution /t:Build /p:Configuration=Release /p:OutDir=$BuildDir /v:minimal }
}
```

> **Note:** psake v5 requires Framework 4.0 or higher. The default is 4.7.2.

## Node.js Projects

### Basic npm Build

```powershell
Properties {
    $ProjectDir = $PSScriptRoot
    $BuildDir = Join-Path $ProjectDir 'dist'
}

Task Default -depends Test

Task Clean {
    if (Test-Path $BuildDir) { Remove-Item $BuildDir -Recurse -Force }
}

Task Install {
    if ($env:CI) {
        exec { npm ci }
    } else {
        exec { npm install }
    }
}

Task Lint -depends Install {
    exec { npm run lint }
}

Task Build -depends Install, Clean {
    exec { npm run build }
}

Task Test -depends Build {
    exec { npm test }
}

Task Publish -depends Test {
    $token = $env:NPM_TOKEN
    Assert (-not [string]::IsNullOrEmpty($token)) "NPM_TOKEN required"
    
    exec { npm config set //registry.npmjs.org/:_authToken $token }
    try {
        exec { npm publish --access public }
    } finally {
        exec { npm config delete //registry.npmjs.org/:_authToken }
    }
}
```

### TypeScript

```powershell
Task TypeCheck -depends Install {
    exec { npx tsc --noEmit }
}

Task Build -depends TypeCheck, Clean {
    exec { npx tsc }
}
```

## Docker Builds

### Basic Docker

```powershell
Properties {
    $ImageName = 'myapp'
    $ImageTag = if ($env:BUILD_NUMBER) { "1.0.$env:BUILD_NUMBER" } else { 'latest' }
    $Registry = $env:DOCKER_REGISTRY
}

Task Default -depends Build

Task Verify {
    exec { docker --version } | Out-Null
    Assert (Test-Path 'Dockerfile') "Dockerfile not found"
}

Task Build -depends Verify {
    exec { docker build -t "${ImageName}:${ImageTag}" . }
}

Task Run -depends Build {
    exec { docker run -d -p 8080:80 --name $ImageName "${ImageName}:${ImageTag}" }
}

Task Stop {
    docker stop $ImageName 2>$null
    docker rm $ImageName 2>$null
}

Task Push -depends Build {
    Assert (-not [string]::IsNullOrEmpty($Registry)) "DOCKER_REGISTRY required"
    Assert (-not [string]::IsNullOrEmpty($env:DOCKER_TOKEN)) "DOCKER_TOKEN required"
    
    $fullTag = "${Registry}/${ImageName}:${ImageTag}"
    
    $env:DOCKER_TOKEN | docker login $Registry -u $env:DOCKER_USERNAME --password-stdin
    exec { docker tag "${ImageName}:${ImageTag}" $fullTag }
    exec { docker push $fullTag }
}
```

### Docker Compose

```powershell
Properties {
    $ComposeFile = Join-Path $PSScriptRoot 'docker-compose.yml'
    $ProjectName = 'myapp'
}

Task Up {
    $env:COMPOSE_PROJECT_NAME = $ProjectName
    exec { docker compose -f $ComposeFile up -d }
}

Task Down {
    $env:COMPOSE_PROJECT_NAME = $ProjectName
    exec { docker compose -f $ComposeFile down }
}

Task Logs {
    $env:COMPOSE_PROJECT_NAME = $ProjectName
    exec { docker compose -f $ComposeFile logs -f }
}
```

## Multi-Technology Stack

```powershell
Properties {
    $BackendDir = Join-Path $PSScriptRoot 'backend'
    $FrontendDir = Join-Path $PSScriptRoot 'frontend'
    $BuildDir = Join-Path $PSScriptRoot 'build'
}

Task Default -depends BuildAll

Task Clean {
    if (Test-Path $BuildDir) { Remove-Item $BuildDir -Recurse -Force }
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}

Task BuildBackend -depends Clean {
    Push-Location $BackendDir
    try {
        exec { dotnet build -c Release -o "$BuildDir/api" }
    } finally {
        Pop-Location
    }
}

Task BuildFrontend -depends Clean {
    Push-Location $FrontendDir
    try {
        exec { npm ci }
        exec { npm run build }
        Copy-Item ./dist/* "$BuildDir/web" -Recurse
    } finally {
        Pop-Location
    }
}

Task BuildAll -depends BuildBackend, BuildFrontend

Task TestAll {
    Push-Location $BackendDir
    try { exec { dotnet test } } finally { Pop-Location }
    
    Push-Location $FrontendDir
    try { exec { npm test } } finally { Pop-Location }
}

Task DockerBuild -depends BuildAll {
    exec { docker build -t myapp:latest . }
}
```
