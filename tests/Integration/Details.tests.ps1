BeforeDiscovery {
    # Test API connectivity and find a known release during discovery phase so -Skip works correctly
    $script:ApiAvailable = $false
    $script:TestRelease = $null
    $script:TestReleaseWithNfo = $null
    $script:TestReleaseWithImdb = $null

    try {
        # Find a release to use for testing
        $response = Invoke-RestMethod -Uri 'https://api.srrdb.com/v1/search/inception/category:x264' -TimeoutSec 10 -ErrorAction Stop
        $script:ApiAvailable = $true

        if ($response.results.Count -gt 0) {
            $script:TestRelease = $response.results[0].release

            # Find a release with NFO
            foreach ($result in $response.results) {
                if ($result.hasNFO -eq 'yes') {
                    $script:TestReleaseWithNfo = $result.release
                    break
                }
            }

            # The IMDB endpoint works with movie releases
            $script:TestReleaseWithImdb = $script:TestRelease
        }
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

    # Re-fetch test data at runtime (BeforeDiscovery variables aren't available here)
    $script:TestRelease = $null
    $script:TestReleaseWithNfo = $null
    $script:TestReleaseWithImdb = $null

    try {
        $response = Invoke-RestMethod -Uri 'https://api.srrdb.com/v1/search/inception/category:x264' -TimeoutSec 10 -ErrorAction Stop

        if ($response.results.Count -gt 0) {
            $script:TestRelease = $response.results[0].release

            foreach ($result in $response.results) {
                if ($result.hasNFO -eq 'yes') {
                    $script:TestReleaseWithNfo = $result.release
                    break
                }
            }

            $script:TestReleaseWithImdb = $script:TestRelease
        }
    }
    catch {
        # Already handled in BeforeDiscovery - tests will skip
        Write-Verbose "API check failed: $($_.Exception.Message)"
    }
}

Describe 'Get-SatRelease Integration' -Tag 'Integration' {
    Context 'Release Details' {
        It 'Should return details for a known release' -Skip:(-not $script:ApiAvailable -or -not $script:TestRelease) {
            $result = Get-SatRelease -ReleaseName $script:TestRelease
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Not -BeNullOrEmpty
        }

        It 'Should return expected properties' -Skip:(-not $script:ApiAvailable -or -not $script:TestRelease) {
            $result = Get-SatRelease -ReleaseName $script:TestRelease
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'Files'
        }

        It 'Should return null for non-existent release' -Skip:(-not $script:ApiAvailable) {
            $result = Get-SatRelease -ReleaseName 'This.Release.Does.Not.Exist.12345.XYZ'
            $result | Should -BeNullOrEmpty
        }

        It 'Should have correct PSTypeName' -Skip:(-not $script:ApiAvailable -or -not $script:TestRelease) {
            $result = Get-SatRelease -ReleaseName $script:TestRelease
            if ($result) {
                $result.PSTypeNames | Should -Contain 'SrrDBAutomationToolkit.Release'
            }
        }
    }

    Context 'Pipeline Support' {
        It 'Should accept pipeline input from Search-SatRelease' -Skip:(-not $script:ApiAvailable) {
            $searchResult = Search-SatRelease -Query 'inception' -MaxResults 1
            if ($searchResult) {
                $details = $searchResult | Get-SatRelease
                $details | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe 'Get-SatNfo Integration' -Tag 'Integration' {
    Context 'NFO Information' {
        It 'Should return NFO info for a release with NFO' -Skip:(-not $script:ApiAvailable -or -not $script:TestReleaseWithNfo) {
            $result = Get-SatNfo -ReleaseName $script:TestReleaseWithNfo
            $result | Should -Not -BeNullOrEmpty
            $result.Release | Should -Not -BeNullOrEmpty
        }

        It 'Should return NFO download URL' -Skip:(-not $script:ApiAvailable -or -not $script:TestReleaseWithNfo) {
            $result = Get-SatNfo -ReleaseName $script:TestReleaseWithNfo
            if ($result) {
                $result.DownloadUrl | Should -Match '^https?://'
            }
        }

        It 'Should download NFO content with -Download switch' -Skip:(-not $script:ApiAvailable -or -not $script:TestReleaseWithNfo) {
            Push-Location $TestDrive
            try {
                $fileInfo = Get-SatNfo -ReleaseName $script:TestReleaseWithNfo -Download
                # -Download saves file and returns FileInfo
                $fileInfo | Should -Not -BeNullOrEmpty
                $fileInfo | Should -BeOfType [System.IO.FileInfo]
                $fileInfo.Name | Should -Match '\.nfo$'
                Test-Path $fileInfo.FullName | Should -BeTrue
            }
            finally {
                Pop-Location
            }
        }

        It 'Should return null for release without NFO' -Skip:(-not $script:ApiAvailable) {
            $result = Get-SatNfo -ReleaseName 'This.Release.Does.Not.Exist.12345.XYZ'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Output Type' {
        It 'Should have correct PSTypeName' -Skip:(-not $script:ApiAvailable -or -not $script:TestReleaseWithNfo) {
            $result = Get-SatNfo -ReleaseName $script:TestReleaseWithNfo
            if ($result) {
                $result.PSTypeNames | Should -Contain 'SrrDBAutomationToolkit.NfoInfo'
            }
        }
    }
}

Describe 'Get-SatImdb Integration' -Tag 'Integration' {
    Context 'IMDB Information' {
        It 'Should return IMDB info for a movie release' -Skip:(-not $script:ApiAvailable -or -not $script:TestReleaseWithImdb) {
            # Not all releases have IMDB info, so we just check it doesn't error
            { Get-SatImdb -ReleaseName $script:TestReleaseWithImdb } | Should -Not -Throw
        }

        It 'Should return expected IMDB properties when available' -Skip:(-not $script:ApiAvailable -or -not $script:TestReleaseWithImdb) {
            $result = Get-SatImdb -ReleaseName $script:TestReleaseWithImdb
            if ($result) {
                $result.PSObject.Properties.Name | Should -Contain 'ImdbId'
                $result.PSObject.Properties.Name | Should -Contain 'Title'
            }
        }

        It 'Should return null for release without IMDB info' -Skip:(-not $script:ApiAvailable) {
            $result = Get-SatImdb -ReleaseName 'This.Release.Does.Not.Exist.12345.XYZ'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Output Type' {
        It 'Should have correct PSTypeName when result exists' -Skip:(-not $script:ApiAvailable -or -not $script:TestReleaseWithImdb) {
            $result = Get-SatImdb -ReleaseName $script:TestReleaseWithImdb
            if ($result) {
                $result.PSTypeNames | Should -Contain 'SrrDBAutomationToolkit.ImdbInfo'
            }
        }
    }
}

Describe 'End-to-End Workflow Integration' -Tag 'Integration' {
    Context 'Search to Details Pipeline' {
        It 'Should support full pipeline: Search -> Get-SatRelease' -Skip:(-not $script:ApiAvailable) {
            $results = Search-SatRelease -Query 'inception' -MaxResults 1 |
                Get-SatRelease

            if ($results) {
                $results.Name | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should support full pipeline: Search -> Get-SatNfo' -Skip:(-not $script:ApiAvailable) {
            $searchResults = Search-SatRelease -Query 'inception' -HasNfo -MaxResults 5

            if ($searchResults) {
                $nfoResults = $searchResults | Get-SatNfo
                # At least some should have NFO info
                $nfoResults | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should support full pipeline: Search -> Get-SatImdb' -Skip:(-not $script:ApiAvailable) {
            $searchResults = Search-SatRelease -Query 'inception' -Category 'x264' -MaxResults 3

            if ($searchResults) {
                # Some movie releases should have IMDB info
                { $searchResults | Get-SatImdb } | Should -Not -Throw
            }
        }
    }
}
