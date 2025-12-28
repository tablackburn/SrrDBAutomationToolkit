BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'SrrDBAutomationToolkit'

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\Join-SatUri.ps1')
}

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
    }
}
