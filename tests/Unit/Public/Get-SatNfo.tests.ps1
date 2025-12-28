BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'SrrDBAutomationToolkit'

    # Import required functions
    . (Join-Path $ModuleRoot 'Private\Invoke-SatApi.ps1')
    . (Join-Path $ModuleRoot 'Private\Join-SatUri.ps1')
    . (Join-Path $ModuleRoot 'Public\Get-SatNfo.ps1')
}

Describe 'Get-SatNfo' {
    BeforeAll {
        Mock Invoke-SatApi {
            return @{
                nfo     = 'group.nfo'
                nfolink = 'https://www.srrdb.com/download/file/Test.Release/group.nfo'
            }
        }
    }

    Context 'Info retrieval' {
        It 'Should return NFO info' {
            $result = Get-SatNfo -ReleaseName 'Test.Release.2023-GROUP'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return object with correct properties' {
            $result = Get-SatNfo -ReleaseName 'Test.Release.2023-GROUP'
            $result.Release | Should -Be 'Test.Release.2023-GROUP'
            $result.NfoFile | Should -Be 'group.nfo'
            $result.DownloadUrl | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Download functionality' {
        BeforeAll {
            Mock Invoke-RestMethod { return 'NFO content here' }
        }

        It 'Should download NFO content when -Download specified' {
            $result = Get-SatNfo -ReleaseName 'Test.Release.2023-GROUP' -Download
            $result | Should -Be 'NFO content here'
        }
    }

    Context 'Pipeline support' {
        It 'Should accept pipeline input' {
            $result = 'Test.Release.2023-GROUP' | Get-SatNfo
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should accept Release property from pipeline' {
            $searchResult = [PSCustomObject]@{ Release = 'Test.Release.2023-GROUP' }
            $result = $searchResult | Get-SatNfo
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error handling' {
        It 'Should throw on API error response' {
            Mock Invoke-SatApi { return @{ error = 'Not found' } }
            { Get-SatNfo -ReleaseName 'NonExistent' } | Should -Throw "*srrDB API error*"
        }

        It 'Should warn when no NFO found' {
            Mock Invoke-SatApi { return @{ nfo = $null; nfolink = $null } }
            $result = Get-SatNfo -ReleaseName 'NoNfo.Release' -WarningVariable warnings -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $warnings | Should -Not -BeNullOrEmpty
        }
    }
}
