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
Describe 'Get-SatRelease' {
    BeforeAll {
        Mock Invoke-SatApi {
            return @{
                name           = 'Test.Release.2023-GROUP'
                files          = @(@{ name = 'file.mkv'; size = 1024 })
                archived       = @(@{ name = 'test.rar' })
                'archived-files' = @(@{ name = 'test.r00' })
                'srr-size'     = 12345
                hasNFO         = 'yes'
                hasSRS         = 'no'
            }
        }
    }

    Context 'Basic retrieval' {
        It 'Should return release details' {
            $result = Get-SatRelease -ReleaseName 'Test.Release.2023-GROUP'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return object with correct properties' {
            $result = Get-SatRelease -ReleaseName 'Test.Release.2023-GROUP'
            $result.Name | Should -Be 'Test.Release.2023-GROUP'
            $result.Files | Should -Not -BeNullOrEmpty
            $result.Archived | Should -Not -BeNullOrEmpty
            $result.SrrSize | Should -Be 12345
        }

        It 'Should parse HasNfo boolean correctly' {
            $result = Get-SatRelease -ReleaseName 'Test.Release.2023-GROUP'
            $result.HasNfo | Should -BeTrue
        }

        It 'Should parse HasSrs boolean correctly' {
            $result = Get-SatRelease -ReleaseName 'Test.Release.2023-GROUP'
            $result.HasSrs | Should -BeFalse
        }
    }

    Context 'Pipeline support' {
        It 'Should accept pipeline input' {
            $result = 'Test.Release.2023-GROUP' | Get-SatRelease
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should accept Release property from pipeline' {
            $searchResult = [PSCustomObject]@{ Release = 'Test.Release.2023-GROUP' }
            $result = $searchResult | Get-SatRelease
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'URL encoding' {
        It 'Should URL-encode release name in API call' {
            Get-SatRelease -ReleaseName 'Release With Spaces'
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'Release%20With%20Spaces'
            }
        }
    }

    Context 'Error handling' {
        It 'Should throw on API error response' {
            Mock Invoke-SatApi { return @{ error = 'Not found' } }
            { Get-SatRelease -ReleaseName 'NonExistent' } | Should -Throw "*srrDB API error*"
        }

        It 'Should warn when release not found' {
            Mock Invoke-SatApi { return @{ name = $null } }
            $result = Get-SatRelease -ReleaseName 'NonExistent' -WarningVariable warnings -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $warnings | Should -Not -BeNullOrEmpty
        }
    }
}
}
