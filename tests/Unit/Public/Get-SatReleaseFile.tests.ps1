[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Pester BeforeAll/It scope'
)]
param()

BeforeDiscovery {
    if ($null -eq $Env:BHBuildOutput) {
        # Populate BuildHelpers env vars so build.psake.ps1's properties block has
        # the values it needs (BHPSModuleManifest, BHProjectName) — when running
        # via ./build.ps1 this happens before psake; running tests in isolation
        # bypasses that, so we do it here.
        $repoRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
        Set-BuildEnvironment -Path $repoRoot -Force
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\build.psake.ps1'
        $invokePsakeParameters = @{
            TaskList  = 'Build'
            BuildFile = $buildFilePath
        }
        Invoke-psake @invokePsakeParameters
    }

    $projectRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    $sourceManifest = Join-Path -Path $projectRoot -ChildPath "$Env:BHProjectName/$Env:BHProjectName.psd1"
    $moduleVersion = (Import-PowerShellDataFile -Path $sourceManifest).ModuleVersion
    $Env:BHBuildOutput = Join-Path -Path $projectRoot -ChildPath "Output/$Env:BHProjectName/$moduleVersion"
}

BeforeAll {
    $moduleManifestPath = Join-Path -Path $Env:BHBuildOutput -ChildPath "$Env:BHProjectName.psd1"
    Get-Module -Name $Env:BHProjectName | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Force -ErrorAction 'Stop'
}

InModuleScope $Env:BHProjectName {
Describe 'Get-SatReleaseFile' {
    BeforeAll {
        # Create a temp directory for tests
        $script:testDir = Join-Path $TestDrive 'GetSatReleaseFile'
        New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null

        # Mock the underlying functions
        Mock Search-SatRelease {
            return [PSCustomObject]@{
                Release = 'Test.Release-GROUP'
                Date    = '2024-01-01'
                HasNfo  = $true
                HasSrs  = $false
            }
        }

        Mock Get-SatSrr {
            if ($PassThru) {
                return [PSCustomObject]@{
                    FullName = "$script:testDir\Test.Release-GROUP.srr"
                    Name     = "Test.Release-GROUP.srr"
                }
            }
        }

        Mock Get-SatRelease {
            return [PSCustomObject]@{
                Name  = 'Test.Release-GROUP'
                Files = @(
                    @{ name = 'Proof/proof.jpg' }       # Should be downloaded (proof image)
                    @{ name = 'release.nfo' }           # Should be downloaded
                    @{ name = 'release.sfv' }           # Should be downloaded
                    @{ name = 'info.txt' }              # Should be downloaded (txt file)
                    @{ name = 'Proof/proof2.JPG' }      # Should be downloaded (uppercase extension)
                    @{ name = 'release.srr' }           # Should be skipped (SRR)
                    @{ name = 'Sample/sample.srs' }     # Should be skipped (SRS)
                    @{ name = 'release.rar' }           # Should be skipped (not hosted)
                    @{ name = 'release.r00' }           # Should be skipped (not hosted)
                    @{ name = 'Sample/sample.mkv' }     # Should be skipped (not hosted)
                    @{ name = 'README' }                # Should be skipped (no extension)
                    @{ name = $null }                   # Should be skipped (null name)
                    @{ name = '   ' }                   # Should be skipped (whitespace-only)
                )
            }
        }

        Mock Get-SatFile {
            if ($PassThru) {
                return [PSCustomObject]@{
                    FullName = "$script:testDir\$($FileName)"
                    Name     = $FileName
                }
            }
        }
    }

    Context 'Search functionality' {
        It 'Should search for release by exact name first' {
            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false
            Should -Invoke Search-SatRelease -ParameterFilter {
                $ReleaseName -eq 'Test.Release-GROUP'
            }
        }

        It 'Should fall back to fuzzy search when exact match fails' {
            Mock Search-SatRelease {
                if ($ReleaseName) { return $null }
                if ($Query) {
                    return [PSCustomObject]@{
                        Release = 'Test.Release-GROUP'
                        Date    = '2024-01-01'
                    }
                }
            }

            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false
            Should -Invoke Search-SatRelease -Times 2
        }

        It 'Should throw when release not found' {
            Mock Search-SatRelease { return $null }
            { Get-SatReleaseFile -ReleaseName 'NonExistent.Release' -OutPath $script:testDir -Confirm:$false } |
                Should -Throw "*Release not found on srrDB*"
        }

        It 'Should select exact match from multiple results' {
            Mock Search-SatRelease {
                return @(
                    [PSCustomObject]@{ Release = 'Other.Release-GROUP' }
                    [PSCustomObject]@{ Release = 'Test.Release-GROUP' }
                    [PSCustomObject]@{ Release = 'Another.Release-GROUP' }
                )
            }

            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false
            Should -Invoke Get-SatSrr -ParameterFilter {
                $ReleaseName -eq 'Test.Release-GROUP'
            }
        }

        It 'Should use first result when no exact match found in array' {
            Mock Search-SatRelease {
                return @(
                    [PSCustomObject]@{ Release = 'Similar.Release-GROUP1' }
                    [PSCustomObject]@{ Release = 'Similar.Release-GROUP2' }
                )
            }

            Get-SatReleaseFile -ReleaseName 'NonMatching.Release' -OutPath $script:testDir -Confirm:$false
            Should -Invoke Get-SatSrr -ParameterFilter {
                $ReleaseName -eq 'Similar.Release-GROUP1'
            }
        }
    }

    Context 'SRR download' {
        It 'Should download SRR file' {
            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false
            Should -Invoke Get-SatSrr -ParameterFilter {
                $ReleaseName -eq 'Test.Release-GROUP' -and
                $OutPath -eq $script:testDir
            }
        }

        It 'Should use current directory when OutPath not specified' {
            Push-Location $script:testDir
            try {
                Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -Confirm:$false
                Should -Invoke Get-SatSrr -ParameterFilter {
                    $OutPath -eq $script:testDir
                }
            }
            finally {
                Pop-Location
            }
        }
    }

    Context 'Additional files download' {
        It 'Should get release details for additional files' {
            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false
            Should -Invoke Get-SatRelease
        }

        It 'Should download proof, nfo, and sfv files' {
            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false
            Should -Invoke Get-SatFile -ParameterFilter { $FileName -eq 'Proof/proof.jpg' }
            Should -Invoke Get-SatFile -ParameterFilter { $FileName -eq 'release.nfo' }
            Should -Invoke Get-SatFile -ParameterFilter { $FileName -eq 'release.sfv' }
        }

        It 'Should skip SRR and SRS files' {
            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false
            Should -Not -Invoke Get-SatFile -ParameterFilter { $FileName -eq 'release.srr' }
            Should -Not -Invoke Get-SatFile -ParameterFilter { $FileName -eq 'Sample/sample.srs' }
        }

        It 'Should skip files not hosted by srrDB (RAR, media)' {
            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false
            Should -Not -Invoke Get-SatFile -ParameterFilter { $FileName -eq 'release.rar' }
            Should -Not -Invoke Get-SatFile -ParameterFilter { $FileName -eq 'release.r00' }
            Should -Not -Invoke Get-SatFile -ParameterFilter { $FileName -eq 'Sample/sample.mkv' }
        }

        It 'Should skip files without extensions' {
            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false
            Should -Not -Invoke Get-SatFile -ParameterFilter { $FileName -eq 'README' }
        }

        It 'Should skip files with null or whitespace names' {
            # This test verifies that null and whitespace-only filenames don't cause errors
            # The mock includes @{ name = $null } and @{ name = '   ' } entries
            { Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Should download txt files' {
            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false
            Should -Invoke Get-SatFile -ParameterFilter { $FileName -eq 'info.txt' }
        }

        It 'Should handle extensions case-insensitively' {
            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false
            Should -Invoke Get-SatFile -ParameterFilter { $FileName -eq 'Proof/proof2.JPG' }
        }

        It 'Should skip existing files' {
            Mock Test-Path { return $true }
            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false
            Should -Not -Invoke Get-SatFile
        }

        It 'Should skip additional files when SkipAdditionalFiles is specified' {
            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -SkipAdditionalFiles -Confirm:$false
            Should -Not -Invoke Get-SatRelease
            Should -Not -Invoke Get-SatFile
        }
    }

    Context 'PassThru parameter' {
        It 'Should return result object when PassThru is specified' {
            $result = Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.ReleaseName | Should -Be 'Test.Release-GROUP'
            $result.SrrFile | Should -Not -BeNullOrEmpty
        }

        It 'Should return nothing by default' {
            $result = Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Pipeline support' {
        It 'Should accept pipeline input' {
            'Test.Release-GROUP' | Get-SatReleaseFile -OutPath $script:testDir -Confirm:$false
            Should -Invoke Get-SatSrr
        }

        It 'Should accept Release property from pipeline' {
            $searchResult = [PSCustomObject]@{ Release = 'Test.Release-GROUP' }
            $searchResult | Get-SatReleaseFile -OutPath $script:testDir -Confirm:$false
            Should -Invoke Get-SatSrr
        }
    }

    Context 'ShouldProcess support' {
        It 'Should support WhatIf' {
            Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -WhatIf
            Should -Not -Invoke Get-SatSrr
            Should -Not -Invoke Get-SatFile
        }
    }

    Context 'Error handling' {
        It 'Should throw when OutPath directory does not exist' {
            { Get-SatReleaseFile -ReleaseName 'Test.Release' -OutPath 'C:\NonExistent\Path\That\Does\Not\Exist' } |
                Should -Throw "*Directory does not exist*"
        }

        It 'Should continue when additional file download fails' {
            Mock Get-SatFile { throw "Download failed" }
            # Should not throw, just warn
            { Get-SatReleaseFile -ReleaseName 'Test.Release-GROUP' -OutPath $script:testDir -Confirm:$false } |
                Should -Not -Throw
        }
    }
}
}
