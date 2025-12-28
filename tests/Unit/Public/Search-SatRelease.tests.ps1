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
                resultsCount = 2
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

    Context 'Pagination' {
        It 'Should automatically paginate through all results' {
            $callCount = 0
            Mock Invoke-SatApi {
                $callCount++
                if ($Uri -notmatch 'skip:') {
                    # First page
                    return @{
                        resultsCount = 50
                        results = @(1..45 | ForEach-Object {
                            @{ release = "Release.$_"; date = '2023-01-01'; hasNFO = 'yes'; hasSRS = 'no' }
                        })
                    }
                }
                else {
                    # Second page (partial)
                    return @{
                        resultsCount = 50
                        results = @(46..50 | ForEach-Object {
                            @{ release = "Release.$_"; date = '2023-01-01'; hasNFO = 'yes'; hasSRS = 'no' }
                        })
                    }
                }
            }

            $results = Search-SatRelease -Query 'Test'
            $results | Should -HaveCount 50
            Should -Invoke Invoke-SatApi -Times 2
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
            Mock Invoke-SatApi { return @{ resultsCount = 0; results = @() } }
            $results = Search-SatRelease -Query 'NonExistent'
            $results | Should -BeNullOrEmpty
        }
    }

    Context 'New search filters' {
        It 'Should call API with Foreign filter' {
            Search-SatRelease -Query 'Test' -Foreign
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'foreign:yes'
            }
        }

        It 'Should call API with Confirmed filter' {
            Search-SatRelease -Query 'Test' -Confirmed
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'confirmed:yes'
            }
        }

        It 'Should call API with RarHash filter' {
            Search-SatRelease -Query 'Test' -RarHash 'ABC123'
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'rarhash:ABC123'
            }
        }

        It 'Should call API with ArchiveCrc filter' {
            Search-SatRelease -Query 'Test' -ArchiveCrc 'DEADBEEF'
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'archive-crc:DEADBEEF'
            }
        }

        It 'Should call API with ArchiveSize filter' {
            Search-SatRelease -Query 'Test' -ArchiveSize 1048576
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'archive-size:1048576'
            }
        }

        It 'Should call API with InternetSubtitlesDbHash filter' {
            Search-SatRelease -Query 'Test' -InternetSubtitlesDbHash 'HASH123'
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'isdbhash:HASH123'
            }
        }

        It 'Should call API with Compressed filter' {
            Search-SatRelease -Query 'Test' -Compressed
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'compressed:yes'
            }
        }

        It 'Should call API with Order filter' {
            Search-SatRelease -Query 'Test' -Order 'date-desc'
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'order:date-desc'
            }
        }

        It 'Should call API with Country filter' {
            Search-SatRelease -Query 'Test' -Country 'US'
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'country:US'
            }
        }

        It 'Should call API with Language filter' {
            Search-SatRelease -Query 'Test' -Language 'German'
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'language:German'
            }
        }

        It 'Should call API with SampleFilename filter' {
            Search-SatRelease -Query 'Test' -SampleFilename 'sample.avi'
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'store-real-filename:sample.avi'
            }
        }

        It 'Should call API with SampleCrc filter' {
            Search-SatRelease -Query 'Test' -SampleCrc 'ABCD1234'
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'store-real-crc:ABCD1234'
            }
        }
    }

    Context 'Combined new and existing filters' {
        It 'Should combine multiple new filters' {
            Search-SatRelease -Query 'Test' -Foreign -Confirmed -Order 'date-desc' -Country 'DE'
            Should -Invoke Invoke-SatApi -ParameterFilter {
                $Uri -match 'foreign:yes' -and
                $Uri -match 'confirmed:yes' -and
                $Uri -match 'order:date-desc' -and
                $Uri -match 'country:DE'
            }
        }
    }
}
