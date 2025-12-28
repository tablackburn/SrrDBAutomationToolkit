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

Describe 'srrDB API Integration' -Tag 'Integration' {
    Context 'API Connectivity' {
        It 'Should reach the srrDB API' -Skip:(-not $script:ApiAvailable) {
            $response = Invoke-RestMethod -Uri 'https://api.srrdb.com/v1/search/test' -ErrorAction Stop
            $response | Should -Not -BeNullOrEmpty
        }

        It 'Should return JSON with expected structure' -Skip:(-not $script:ApiAvailable) {
            $response = Invoke-RestMethod -Uri 'https://api.srrdb.com/v1/search/test' -ErrorAction Stop
            $response.PSObject.Properties.Name | Should -Contain 'results'
            $response.PSObject.Properties.Name | Should -Contain 'resultsCount'
        }
    }

    Context 'API Endpoints' {
        It 'Should return results from search endpoint' -Skip:(-not $script:ApiAvailable) {
            $response = Invoke-RestMethod -Uri 'https://api.srrdb.com/v1/search/inception' -ErrorAction Stop
            $response.results | Should -Not -BeNullOrEmpty
        }

        It 'Should return details from details endpoint' -Skip:(-not $script:ApiAvailable) {
            # First find a release to get details for
            $search = Invoke-RestMethod -Uri 'https://api.srrdb.com/v1/search/inception' -ErrorAction Stop
            if ($search.results.Count -gt 0) {
                $releaseName = $search.results[0].release
                $encodedName = [System.Uri]::EscapeDataString($releaseName)
                $details = Invoke-RestMethod -Uri "https://api.srrdb.com/v1/details/$encodedName" -ErrorAction Stop
                $details | Should -Not -BeNullOrEmpty
                $details.name | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should handle non-existent release gracefully' -Skip:(-not $script:ApiAvailable) {
            $response = Invoke-RestMethod -Uri 'https://api.srrdb.com/v1/details/This.Release.Does.Not.Exist.12345' -ErrorAction Stop
            # API returns empty or error object for non-existent releases
            ($response.name -eq $null -or $response.error) | Should -BeTrue
        }
    }

    Context 'Rate Limiting Behavior' {
        It 'Should handle multiple rapid requests' -Skip:(-not $script:ApiAvailable) {
            # Make several quick requests to test rate limiting handling
            $results = @()
            for ($i = 0; $i -lt 3; $i++) {
                $response = Invoke-RestMethod -Uri 'https://api.srrdb.com/v1/search/test' -ErrorAction Stop
                $results += $response
                Start-Sleep -Milliseconds 100
            }
            $results | Should -HaveCount 3
        }
    }
}
