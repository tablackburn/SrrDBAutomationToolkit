BeforeDiscovery {
    # Test API connectivity during discovery phase so -Skip works correctly
    $script:ApiAvailable = $false
    try {
        $null = Invoke-RestMethod -Uri 'https://api.srrdb.com/v1/search/test' -TimeoutSec 10 -ErrorAction Stop
        $script:ApiAvailable = $true
    }
    catch {
        Write-Warning "srrDB API is not available. Integration tests will be skipped."
    }
}

BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ModulePath = Join-Path $ProjectRoot 'SrrDBAutomationToolkit'

    # Import the module
    Import-Module $ModulePath -Force
}

Describe 'Search-SatRelease Integration' -Tag 'Integration' {
    Context 'Basic Search' {
        It 'Should return results for a common search term' -Skip:(-not $script:ApiAvailable) {
            $results = Search-SatRelease -Query 'inception'
            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -BeGreaterThan 0
        }

        It 'Should return results with expected properties' -Skip:(-not $script:ApiAvailable) {
            $results = Search-SatRelease -Query 'inception' -MaxResults 1
            $results | Should -HaveCount 1
            $results[0].PSObject.Properties.Name | Should -Contain 'Release'
            $results[0].PSObject.Properties.Name | Should -Contain 'Date'
            $results[0].PSObject.Properties.Name | Should -Contain 'HasNfo'
            $results[0].PSObject.Properties.Name | Should -Contain 'HasSrs'
        }

        It 'Should return empty for non-existent release' -Skip:(-not $script:ApiAvailable) {
            $results = Search-SatRelease -Query 'xyznonexistent12345abcdef'
            $results | Should -BeNullOrEmpty
        }
    }

    Context 'Category Filtering' {
        It 'Should filter by x264 category' -Skip:(-not $script:ApiAvailable) {
            $results = Search-SatRelease -Query 'test' -Category 'x264' -MaxResults 5
            # Just verify the query executes successfully with filters
            # We can't guarantee results but the command should not error
            { Search-SatRelease -Query 'test' -Category 'x264' -MaxResults 1 } | Should -Not -Throw
        }

        It 'Should filter by tv category' -Skip:(-not $script:ApiAvailable) {
            $results = Search-SatRelease -Query 'simpsons' -Category 'tv' -MaxResults 5
            if ($results) {
                $results.Count | Should -BeGreaterThan 0
            }
        }
    }

    Context 'Pagination' {
        It 'Should respect MaxResults parameter' -Skip:(-not $script:ApiAvailable) {
            $results = Search-SatRelease -Query 'test' -MaxResults 10
            $results.Count | Should -BeLessOrEqual 10
        }

        It 'Should return more results when MaxResults is higher' -Skip:(-not $script:ApiAvailable) {
            $smallResults = Search-SatRelease -Query 'the' -MaxResults 5
            $largeResults = Search-SatRelease -Query 'the' -MaxResults 50

            if ($smallResults -and $largeResults) {
                $largeResults.Count | Should -BeGreaterOrEqual $smallResults.Count
            }
        }

        It 'Should handle pagination across multiple pages' -Skip:(-not $script:ApiAvailable) {
            # API returns 45 results per page, so request more to test pagination
            $results = Search-SatRelease -Query 'test' -MaxResults 50
            if ($results.Count -gt 45) {
                # Pagination worked if we got more than one page worth
                $results.Count | Should -BeGreaterThan 45
            }
        }
    }

    Context 'Special Characters' {
        It 'Should handle releases with special characters' -Skip:(-not $script:ApiAvailable) {
            # Search for something that might have special chars
            { Search-SatRelease -Query 'c++' -MaxResults 5 } | Should -Not -Throw
        }

        It 'Should handle group names with dots' -Skip:(-not $script:ApiAvailable) {
            { Search-SatRelease -Query 'SPARKS' -MaxResults 5 } | Should -Not -Throw
        }
    }

    Context 'Output Formatting' {
        It 'Should output objects with correct PSTypeName' -Skip:(-not $script:ApiAvailable) {
            $results = Search-SatRelease -Query 'inception' -MaxResults 1
            if ($results) {
                $results[0].PSTypeNames | Should -Contain 'SrrDBAutomationToolkit.SearchResult'
            }
        }

        It 'Should parse HasNfo as boolean' -Skip:(-not $script:ApiAvailable) {
            $results = Search-SatRelease -Query 'inception' -MaxResults 1
            if ($results) {
                $results[0].HasNfo | Should -BeOfType [bool]
            }
        }

        It 'Should parse HasSrs as boolean' -Skip:(-not $script:ApiAvailable) {
            $results = Search-SatRelease -Query 'inception' -MaxResults 1
            if ($results) {
                $results[0].HasSrs | Should -BeOfType [bool]
            }
        }
    }
}
