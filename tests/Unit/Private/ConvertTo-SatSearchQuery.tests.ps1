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

    Context 'Combined parameters' {
        It 'Should combine multiple filters' {
            $result = ConvertTo-SatSearchQuery -Query 'Inception' -Category 'x264' -HasNfo -Group 'SPARKS'
            $result | Should -Match 'inception'
            $result | Should -Match 'category:x264'
            $result | Should -Match 'nfo:yes'
            $result | Should -Match 'group:SPARKS'
        }
    }
}
