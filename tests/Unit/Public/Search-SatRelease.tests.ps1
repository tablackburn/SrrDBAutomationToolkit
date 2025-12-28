BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'SrrDBAutomationToolkit'

    # Import required functions
    . (Join-Path $ModuleRoot 'Private\Invoke-SatApi.ps1')
    . (Join-Path $ModuleRoot 'Private\Join-SatUri.ps1')
    . (Join-Path $ModuleRoot 'Private\ConvertTo-SatSearchQuery.ps1')
    . (Join-Path $ModuleRoot 'Public\Search-SatRelease.ps1')
}

Describe 'Search-SatRelease' {
    BeforeAll {
        Mock Invoke-SatApi {
            return @{
                results = @(
                    @{
                        release = 'Test.Release.2023-GROUP'
                        date    = '2023-01-15'
                        hasNFO  = 'yes'
                        hasSRS  = 'no'
                    },
                    @{
                        release = 'Another.Release.2023-TEAM'
                        date    = '2023-01-16'
                        hasNFO  = 'no'
                        hasSRS  = 'yes'
                    }
                )
            }
        }
    }

    Context 'Basic search' {
        It 'Should return search results' {
            $results = Search-SatRelease -Query 'Test'
            $results | Should -HaveCount 2
        }

        It 'Should return objects with correct properties' {
            $results = Search-SatRelease -Query 'Test'
            $results[0].PSObject.Properties.Name | Should -Contain 'Release'
            $results[0].PSObject.Properties.Name | Should -Contain 'Date'
            $results[0].PSObject.Properties.Name | Should -Contain 'HasNfo'
            $results[0].PSObject.Properties.Name | Should -Contain 'HasSrs'
        }

        It 'Should parse HasNfo boolean correctly' {
            $results = Search-SatRelease -Query 'Test'
            $results[0].HasNfo | Should -BeTrue
            $results[1].HasNfo | Should -BeFalse
        }

        It 'Should parse HasSrs boolean correctly' {
            $results = Search-SatRelease -Query 'Test'
            $results[0].HasSrs | Should -BeFalse
            $results[1].HasSrs | Should -BeTrue
        }
    }

    Context 'Search filters' {
        It 'Should call API with category filter' {
            Search-SatRelease -Query 'Test' -Category 'xvid'
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'category:xvid'
            }
        }

        It 'Should call API with HasNfo filter' {
            Search-SatRelease -Query 'Test' -HasNfo
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'nfo:yes'
            }
        }

        It 'Should call API with Group filter' {
            Search-SatRelease -Query 'Test' -Group 'SPARKS'
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'group:SPARKS'
            }
        }
    }

    Context 'ReleaseName search' {
        It 'Should use r: prefix for exact release name' {
            Search-SatRelease -ReleaseName 'Exact.Release.Name-GROUP'
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'r:Exact\.Release\.Name-GROUP'
            }
        }
    }

    Context 'MaxResults parameter' {
        It 'Should limit results when MaxResults is specified' {
            $results = Search-SatRelease -Query 'Test' -MaxResults 1
            $results | Should -HaveCount 1
        }
    }

    Context 'Skip parameter' {
        It 'Should call API with skip filter' {
            Search-SatRelease -Query 'Test' -Skip 100
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'skip:100'
            }
        }
    }

    Context 'Error handling' {
        It 'Should throw on API error response' {
            Mock Invoke-SatApi { return @{ error = 'Rate limit exceeded' } }
            { Search-SatRelease -Query 'Test' } | Should -Throw "*srrDB API error*"
        }
    }

    Context 'Empty results' {
        It 'Should handle empty results gracefully' {
            Mock Invoke-SatApi { return @{ results = @() } }
            $results = Search-SatRelease -Query 'NonExistent'
            $results | Should -BeNullOrEmpty
        }
    }
}
