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
Describe 'Join-SatUri' {
    Context 'Basic URI construction' {
        It 'Should use default base URI' {
            $result = Join-SatUri -Endpoint '/details/Some.Release'
            $result | Should -Be 'https://api.srrdb.com/v1/details/Some.Release'
        }

        It 'Should join custom base URI and endpoint' {
            $result = Join-SatUri -BaseUri 'https://api.example.com/v2' -Endpoint '/search/test'
            $result | Should -Be 'https://api.example.com/v2/search/test'
        }

        It 'Should handle trailing slash on base URI' {
            $result = Join-SatUri -BaseUri 'https://api.srrdb.com/v1/' -Endpoint '/details/test'
            $result | Should -Be 'https://api.srrdb.com/v1/details/test'
        }

        It 'Should handle missing leading slash on endpoint' {
            $result = Join-SatUri -Endpoint 'details/test'
            $result | Should -Be 'https://api.srrdb.com/v1/details/test'
        }
    }

    Context 'Query string parameters' {
        It 'Should append query string' {
            $result = Join-SatUri -Endpoint '/search/test' -QueryString 'limit=10'
            $result | Should -Be 'https://api.srrdb.com/v1/search/test?limit=10'
        }

        It 'Should append query string with multiple parameters' {
            $queryString = 'limit=10&offset=20'
            $result = Join-SatUri -Endpoint '/search/test' -QueryString $queryString
            $result | Should -Match 'limit=10'
            $result | Should -Match 'offset=20'
            $result | Should -Match '\?'
        }
    }

    Context 'Parameter validation' {
        It 'Should throw on null Endpoint' {
            { Join-SatUri -Endpoint $null } | Should -Throw
        }

        It 'Should throw on empty Endpoint' {
            { Join-SatUri -Endpoint '' } | Should -Throw
        }

        It 'Should throw on invalid URI format for BaseUri' {
            { Join-SatUri -BaseUri 'not-a-uri' -Endpoint '/test' } | Should -Throw "*Failed to join URI*"
        }

        It 'Should throw when QueryString contains invalid characters' {
            { Join-SatUri -Endpoint '/test' -QueryString 'param=<script>alert(1)</script>' } |
                Should -Throw "*QueryString contains invalid characters*"
        }

        It 'Should throw when QueryString contains control characters' {
            { Join-SatUri -Endpoint '/test' -QueryString "param=value`0injected" } |
                Should -Throw "*QueryString contains invalid characters*"
        }

        It 'Should throw when QueryString contains quotes' {
            { Join-SatUri -Endpoint '/test' -QueryString "param='value'" } |
                Should -Throw "*QueryString contains invalid characters*"
        }
    }
}
}
