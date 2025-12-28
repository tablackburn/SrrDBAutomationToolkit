BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'SrrDBAutomationToolkit'

    # Import required functions
    . (Join-Path $ModuleRoot 'Private\Invoke-SatApi.ps1')
    . (Join-Path $ModuleRoot 'Private\Join-SatUri.ps1')
    . (Join-Path $ModuleRoot 'Public\Get-SatRelease.ps1')
}

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
