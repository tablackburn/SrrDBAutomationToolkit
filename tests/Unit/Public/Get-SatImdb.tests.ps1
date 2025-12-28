BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'SrrDBAutomationToolkit'

    # Import required functions
    . (Join-Path $ModuleRoot 'Private\Invoke-SatApi.ps1')
    . (Join-Path $ModuleRoot 'Private\Join-SatUri.ps1')
    . (Join-Path $ModuleRoot 'Public\Get-SatImdb.ps1')
}

Describe 'Get-SatImdb' {
    BeforeAll {
        Mock Invoke-SatApi {
            return @{
                imdbID   = 'tt1375666'
                title    = 'Inception'
                year     = '2010'
                rating   = '8.8'
                votes    = '2000000'
                genre    = 'Action, Sci-Fi, Thriller'
                director = 'Christopher Nolan'
                actors   = 'Leonardo DiCaprio, Joseph Gordon-Levitt'
            }
        }
    }

    Context 'Basic retrieval' {
        It 'Should return IMDB info' {
            $result = Get-SatImdb -ReleaseName 'Inception.2010.1080p-GROUP'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return object with correct properties' {
            $result = Get-SatImdb -ReleaseName 'Inception.2010.1080p-GROUP'
            $result.Release | Should -Be 'Inception.2010.1080p-GROUP'
            $result.ImdbId | Should -Be 'tt1375666'
            $result.Title | Should -Be 'Inception'
            $result.Year | Should -Be '2010'
            $result.Rating | Should -Be '8.8'
            $result.Director | Should -Be 'Christopher Nolan'
        }
    }

    Context 'Pipeline support' {
        It 'Should accept pipeline input' {
            $result = 'Inception.2010.1080p-GROUP' | Get-SatImdb
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should accept Release property from pipeline' {
            $searchResult = [PSCustomObject]@{ Release = 'Inception.2010.1080p-GROUP' }
            $result = $searchResult | Get-SatImdb
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error handling' {
        It 'Should throw on API error response' {
            Mock Invoke-SatApi { return @{ error = 'Not found' } }
            { Get-SatImdb -ReleaseName 'NonExistent' } | Should -Throw "*srrDB API error*"
        }

        It 'Should warn when no IMDB info found' {
            Mock Invoke-SatApi { return @{ imdbID = $null; imdb = $null } }
            $result = Get-SatImdb -ReleaseName 'No.Imdb.Release' -WarningVariable warnings -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $warnings | Should -Not -BeNullOrEmpty
        }
    }
}
