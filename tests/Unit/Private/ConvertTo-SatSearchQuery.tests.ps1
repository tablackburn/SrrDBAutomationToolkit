BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'SrrDBAutomationToolkit'

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\ConvertTo-SatSearchQuery.ps1')
}

Describe 'ConvertTo-SatSearchQuery' {
    Context 'Query parameter' {
        It 'Should convert simple query to lowercase path' {
            $result = ConvertTo-SatSearchQuery -Query 'Inception'
            $result | Should -Be 'inception'
        }

        It 'Should convert multi-word query to slash-separated path' {
            $result = ConvertTo-SatSearchQuery -Query 'Harry Potter'
            $result | Should -Be 'harry/potter'
        }

        It 'Should handle multiple spaces between words' {
            $result = ConvertTo-SatSearchQuery -Query 'Harry   Potter'
            $result | Should -Be 'harry/potter'
        }
    }

    Context 'ReleaseName parameter' {
        It 'Should add r: prefix for exact release name' {
            $result = ConvertTo-SatSearchQuery -ReleaseName 'Some.Release.Name-GROUP'
            $result | Should -Be 'r:Some.Release.Name-GROUP'
        }
    }

    Context 'Category parameter' {
        It 'Should add category filter' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Category 'xvid'
            $result | Should -Match 'category:xvid'
        }

        It 'Should convert category to lowercase' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Category 'XVID'
            $result | Should -Match 'category:xvid'
        }
    }

    Context 'Group parameter' {
        It 'Should add group filter' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Group 'SPARKS'
            $result | Should -Match 'group:SPARKS'
        }
    }

    Context 'ImdbId parameter' {
        It 'Should add imdb filter with tt prefix' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -ImdbId 'tt1375666'
            $result | Should -Match 'imdb:tt1375666'
        }

        It 'Should normalize imdb ID without tt prefix' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -ImdbId '1375666'
            $result | Should -Match 'imdb:tt1375666'
        }
    }

    Context 'Switch parameters' {
        It 'Should add nfo:yes when HasNfo is specified' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -HasNfo
            $result | Should -Match 'nfo:yes'
        }

        It 'Should add srs:yes when HasSrs is specified' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -HasSrs
            $result | Should -Match 'srs:yes'
        }
    }

    Context 'Date parameter' {
        It 'Should add date filter' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Date '2023-01-15'
            $result | Should -Match 'date:2023-01-15'
        }
    }

    Context 'Skip parameter' {
        It 'Should add skip filter for pagination' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Skip 100
            $result | Should -Match 'skip:100'
        }

        It 'Should not add skip filter when Skip is 0' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Skip 0
            $result | Should -Not -Match 'skip:'
        }
    }

    Context 'Combined parameters' {
        It 'Should combine multiple filters' {
            $result = ConvertTo-SatSearchQuery -Query 'Inception' -Category 'x264' -HasNfo -Group 'SPARKS'
            $result | Should -Match 'inception'
            $result | Should -Match 'category:x264'
            $result | Should -Match 'nfo:yes'
            $result | Should -Match 'group:SPARKS'
        }
    }

    Context 'Foreign parameter' {
        It 'Should add foreign:yes when Foreign is specified' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Foreign
            $result | Should -Match 'foreign:yes'
        }
    }

    Context 'Confirmed parameter' {
        It 'Should add confirmed:yes when Confirmed is specified' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Confirmed
            $result | Should -Match 'confirmed:yes'
        }
    }

    Context 'RarHash parameter' {
        It 'Should add rarhash filter' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -RarHash 'ABC123'
            $result | Should -Match 'rarhash:ABC123'
        }
    }

    Context 'ArchiveCrc parameter' {
        It 'Should add archive-crc filter' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -ArchiveCrc 'DEADBEEF'
            $result | Should -Match 'archive-crc:DEADBEEF'
        }
    }

    Context 'ArchiveSize parameter' {
        It 'Should add archive-size filter' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -ArchiveSize 1048576
            $result | Should -Match 'archive-size:1048576'
        }

        It 'Should add archive-size filter when size is 0' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -ArchiveSize 0
            $result | Should -Match 'archive-size:0'
        }
    }

    Context 'InternetSubtitlesDbHash parameter' {
        It 'Should add isdbhash filter' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -InternetSubtitlesDbHash 'HASH123'
            $result | Should -Match 'isdbhash:HASH123'
        }
    }

    Context 'Compressed parameter' {
        It 'Should add compressed:yes when Compressed is specified' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Compressed
            $result | Should -Match 'compressed:yes'
        }
    }

    Context 'Order parameter' {
        It 'Should add order filter for date-desc' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Order 'date-desc'
            $result | Should -Match 'order:date-desc'
        }

        It 'Should add order filter for release-asc' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Order 'release-asc'
            $result | Should -Match 'order:release-asc'
        }
    }

    Context 'Country parameter' {
        It 'Should add country filter' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Country 'US'
            $result | Should -Match 'country:US'
        }
    }

    Context 'Language parameter' {
        It 'Should add language filter' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Language 'German'
            $result | Should -Match 'language:German'
        }
    }

    Context 'SampleFilename parameter' {
        It 'Should add store-real-filename filter' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -SampleFilename 'sample.avi'
            $result | Should -Match 'store-real-filename:sample.avi'
        }
    }

    Context 'SampleCrc parameter' {
        It 'Should add store-real-crc filter' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -SampleCrc 'ABCD1234'
            $result | Should -Match 'store-real-crc:ABCD1234'
        }
    }

    Context 'URL encoding for safety' {
        It 'Should URL-encode special characters in RarHash' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -RarHash 'hash/with/slashes'
            $result | Should -Match 'rarhash:hash%2Fwith%2Fslashes'
        }

        It 'Should URL-encode special characters in Country' {
            $result = ConvertTo-SatSearchQuery -Query 'test' -Country 'test value'
            $result | Should -Match 'country:test%20value'
        }
    }
}
