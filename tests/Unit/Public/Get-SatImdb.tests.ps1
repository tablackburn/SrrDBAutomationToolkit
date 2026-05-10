[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Pester BeforeAll/It scope'
)]
param()

BeforeDiscovery {
    if ($null -eq $Env:BHBuildOutput) {
        # Populate BuildHelpers env vars so build.psake.ps1's properties block has
        # the values it needs (BHPSModuleManifest, BHProjectName) — when running
        # via ./build.ps1 this happens before psake; running tests in isolation
        # bypasses that, so we do it here.
        $repoRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
        Set-BuildEnvironment -Path $repoRoot -Force
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\build.psake.ps1'
        $invokePsakeParameters = @{
            TaskList  = 'Build'
            BuildFile = $buildFilePath
        }
        Invoke-psake @invokePsakeParameters
    }

    $projectRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    $sourceManifest = Join-Path -Path $projectRoot -ChildPath "$Env:BHProjectName/$Env:BHProjectName.psd1"
    $moduleVersion = (Import-PowerShellDataFile -Path $sourceManifest).ModuleVersion
    $Env:BHBuildOutput = Join-Path -Path $projectRoot -ChildPath "Output/$Env:BHProjectName/$moduleVersion"
}

BeforeAll {
    $moduleManifestPath = Join-Path -Path $Env:BHBuildOutput -ChildPath "$Env:BHProjectName.psd1"
    Get-Module -Name $Env:BHProjectName | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Force -ErrorAction 'Stop'
}

InModuleScope $Env:BHProjectName {
Describe 'Get-SatImdb' {
    BeforeAll {
        Mock Invoke-SatApi {
            return @{
                imdbID   = 'tt1375666'
                title    = 'Inception'
                year     = '2010'
                rating   = '8.8'
                votes    = '2000000'
                genre    = 'Action, Sci-Fi, Thriller'
                director = 'Christopher Nolan'
                actors   = 'Leonardo DiCaprio, Joseph Gordon-Levitt'
            }
        }
    }

    Context 'Basic retrieval' {
        It 'Should return IMDB info' {
            $result = Get-SatImdb -ReleaseName 'Inception.2010.1080p-GROUP'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return object with correct properties' {
            $result = Get-SatImdb -ReleaseName 'Inception.2010.1080p-GROUP'
            $result.Release | Should -Be 'Inception.2010.1080p-GROUP'
            $result.ImdbId | Should -Be 'tt1375666'
            $result.Title | Should -Be 'Inception'
            $result.Year | Should -Be '2010'
            $result.Rating | Should -Be '8.8'
            $result.Director | Should -Be 'Christopher Nolan'
        }
    }

    Context 'Pipeline support' {
        It 'Should accept pipeline input' {
            $result = 'Inception.2010.1080p-GROUP' | Get-SatImdb
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should accept Release property from pipeline' {
            $searchResult = [PSCustomObject]@{ Release = 'Inception.2010.1080p-GROUP' }
            $result = $searchResult | Get-SatImdb
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error handling' {
        It 'Should throw on API error response' {
            Mock Invoke-SatApi { return @{ error = 'Not found' } }
            { Get-SatImdb -ReleaseName 'NonExistent' } | Should -Throw "*srrDB API error*"
        }

        It 'Should warn when no IMDB info found' {
            Mock Invoke-SatApi { return @{ imdbID = $null; imdb = $null } }
            $result = Get-SatImdb -ReleaseName 'No.Imdb.Release' -WarningVariable warnings -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $warnings | Should -Not -BeNullOrEmpty
        }
    }
}
}
