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
    # Import the built module, not the source tree. Importing from source loads a
    # second copy alongside the one under Output/ that the build task and the unit
    # tests use -- same name, same GUID, two different paths -- and Pester 6 then
    # fails discovery of every InModuleScope file with "Multiple script or manifest
    # modules named 'SrrDBAutomationToolkit' are currently loaded". These files sort
    # before tests/Unit, so they poisoned the session for all of it.
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    if (-not $Env:BHBuildOutput) {
        $sourceManifest = Join-Path $ProjectRoot 'SrrDBAutomationToolkit/SrrDBAutomationToolkit.psd1'
        $moduleVersion = (Import-PowerShellDataFile -Path $sourceManifest).ModuleVersion
        $Env:BHBuildOutput = Join-Path $ProjectRoot "Output/SrrDBAutomationToolkit/$moduleVersion"
    }
    $ModulePath = Join-Path $Env:BHBuildOutput 'SrrDBAutomationToolkit.psd1'

    # Match on path, not just name. Guarding on the name alone would accept whatever
    # copy happens to be loaded -- a developer's source-tree import, say -- and quietly
    # test that instead of the built manifest. Replace it when it is the wrong one, and
    # leave it alone when it is right, so repeated files do not stack up copies.
    $loadedModule = Get-Module -Name 'SrrDBAutomationToolkit'
    $expectedBase = Split-Path -Path $ModulePath -Parent
    if (-not $loadedModule -or $loadedModule.ModuleBase -ne $expectedBase) {
        $loadedModule | Remove-Module -Force -ErrorAction 'SilentlyContinue'
        Import-Module $ModulePath -Force
    }
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
