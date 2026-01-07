BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'SrrDBAutomationToolkit'

    # Import required functions
    . (Join-Path $ModuleRoot 'Public\Get-SatFile.ps1')
}

Describe 'Get-SatFile' {
    BeforeAll {
        Mock Invoke-WebRequest { }
        Mock Get-Item { return [PSCustomObject]@{ FullName = 'C:\Test\proof.jpg' } }
    }

    Context 'Basic download functionality' {
        BeforeAll {
            Push-Location $TestDrive
        }

        AfterAll {
            Pop-Location
        }

        It 'Should download file to specified directory' {
            $testDir = Join-Path $TestDrive 'download_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            Mock Invoke-WebRequest { }

            { Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -OutPath $testDir } | Should -Not -Throw
            Should -Invoke Invoke-WebRequest -Times 1
        }

        It 'Should call Invoke-WebRequest with correct URL' {
            $testDir = Join-Path $TestDrive 'url_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -OutPath $testDir

            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $Uri -eq 'https://www.srrdb.com/download/file/Test.Release-GROUP/proof.jpg'
            }
        }

        It 'Should save file with correct filename' {
            $testDir = Join-Path $TestDrive 'filename_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -OutPath $testDir

            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $OutFile -match 'proof\.jpg$'
            }
        }

        It 'Should download to current directory when OutPath not specified' {
            Mock Invoke-WebRequest { }

            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg'

            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $OutFile -match 'proof\.jpg$'
            }
        }
    }

    Context 'PassThru functionality' {
        It 'Should return FileInfo when -PassThru specified' {
            $testDir = Join-Path $TestDrive 'passthru_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $expectedPath = Join-Path $testDir 'proof.jpg'

            Mock Invoke-WebRequest { }
            Mock Get-Item { [System.IO.FileInfo]::new($expectedPath) } -ParameterFilter { $Path -eq $expectedPath }

            # Create the file so FileInfo works
            New-Item -Path $expectedPath -ItemType File -Force | Out-Null

            $result = Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -OutPath $testDir -PassThru
            $result | Should -BeOfType [System.IO.FileInfo]
        }

        It 'Should return nothing when -PassThru not specified' {
            $testDir = Join-Path $TestDrive 'no_passthru_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            Mock Invoke-WebRequest { }

            $result = Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -OutPath $testDir
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Pipeline support' {
        BeforeAll {
            $script:testDir = Join-Path $TestDrive 'pipeline_test'
            New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
        }

        It 'Should accept ReleaseName from pipeline by property name' {
            Mock Invoke-WebRequest { }

            $obj = [PSCustomObject]@{
                ReleaseName = 'Pipeline.Release-GROUP'
                FileName    = 'test.jpg'
            }
            $obj | Get-SatFile -OutPath $script:testDir
            Should -Invoke Invoke-WebRequest -Times 1
        }

        It 'Should accept Release alias from pipeline' {
            Mock Invoke-WebRequest { }

            $obj = [PSCustomObject]@{
                Release  = 'Alias.Release-GROUP'
                FileName = 'test.jpg'
            }
            $obj | Get-SatFile -OutPath $script:testDir
            Should -Invoke Invoke-WebRequest -Times 1
        }

        It 'Should accept File alias for FileName from pipeline' {
            Mock Invoke-WebRequest { }

            $obj = [PSCustomObject]@{
                ReleaseName = 'File.Alias.Release-GROUP'
                File        = 'aliased.jpg'
            }
            $obj | Get-SatFile -OutPath $script:testDir
            Should -Invoke Invoke-WebRequest -Times 1
        }
    }

    Context 'URL encoding' {
        It 'Should construct correct download URL' {
            $testDir = Join-Path $TestDrive 'url_encoding_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            Mock Invoke-WebRequest { }

            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -OutPath $testDir

            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $Uri -eq 'https://www.srrdb.com/download/file/Test.Release-GROUP/proof.jpg'
            }
        }

        It 'Should preserve forward slashes in file path' {
            $testDir = Join-Path $TestDrive 'slash_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            Mock Invoke-WebRequest { }

            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'Proof/subdir/proof.jpg' -OutPath $testDir

            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $Uri -eq 'https://www.srrdb.com/download/file/Test.Release-GROUP/Proof/subdir/proof.jpg'
            }
        }

        It 'Should URL-encode spaces in release name' {
            $testDir = Join-Path $TestDrive 'space_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            Mock Invoke-WebRequest { }

            Get-SatFile -ReleaseName 'Test Release' -FileName 'file.jpg' -OutPath $testDir

            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $Uri -eq 'https://www.srrdb.com/download/file/Test%20Release/file.jpg'
            }
        }

        It 'Should URL-encode each path segment individually' {
            $testDir = Join-Path $TestDrive 'segment_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            Mock Invoke-WebRequest { }

            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'Sample/sample.mkv' -OutPath $testDir

            Should -Invoke Invoke-WebRequest -ParameterFilter {
                # Forward slashes should be preserved (not encoded as %2F)
                $Uri -like '*Sample/sample.mkv*' -and $Uri -notlike '*%2F*'
            }
        }
    }

    Context 'Filename sanitization' {
        BeforeAll {
            $script:sanitizeDir = Join-Path $TestDrive 'sanitize_test'
            New-Item -Path $script:sanitizeDir -ItemType Directory -Force | Out-Null
            # Get platform-specific invalid characters for filename validation
            $script:invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
        }

        It 'Should produce valid filename without platform-invalid characters' {
            Mock Invoke-WebRequest { }

            # Use forward slash which is invalid on all platforms
            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'Proof/bad_file.jpg' -OutPath $script:sanitizeDir

            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $filename = Split-Path $OutFile -Leaf
                $hasInvalidChar = $false
                foreach ($char in $script:invalidChars) {
                    if ($filename.Contains($char)) { $hasInvalidChar = $true; break }
                }
                -not $hasInvalidChar -and $filename -eq 'bad_file.jpg'
            }
        }

        It 'Should extract filename from path with subdirectories' {
            Mock Invoke-WebRequest { }

            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'Proof/subdir/actual_file.jpg' -OutPath $script:sanitizeDir

            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $OutFile -match 'actual_file\.jpg$'
            }
        }

        It 'Should strip path components and use only leaf filename' {
            Mock Invoke-WebRequest { }

            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'Sample/nested/path/final.jpg' -OutPath $script:sanitizeDir

            Should -Invoke Invoke-WebRequest -ParameterFilter {
                (Split-Path $OutFile -Leaf) -eq 'final.jpg'
            }
        }
    }

    Context 'Error handling' {
        It 'Should throw when OutPath directory does not exist' {
            { Get-SatFile -ReleaseName 'Test.Release' -FileName 'file.jpg' -OutPath 'C:\NonExistent\Path\That\Does\Not\Exist' } |
                Should -Throw "*Directory does not exist*"
        }

        It 'Should throw descriptive error when download fails' {
            $testDir = Join-Path $TestDrive 'error_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            Mock Invoke-WebRequest { throw "404 Not Found" }

            { Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'missing.jpg' -OutPath $testDir } |
                Should -Throw "*Failed to download*"
        }

        It 'Should include release and filename in error message' {
            $testDir = Join-Path $TestDrive 'error_msg_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            Mock Invoke-WebRequest { throw "Connection failed" }

            { Get-SatFile -ReleaseName 'Some.Release-GRP' -FileName 'proof.jpg' -OutPath $testDir } |
                Should -Throw "*proof.jpg*Some.Release-GRP*"
        }
    }

    Context 'WhatIf support' {
        It 'Should not download when -WhatIf specified' {
            $testDir = Join-Path $TestDrive 'whatif_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            Mock Invoke-WebRequest { }

            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -OutPath $testDir -WhatIf

            Should -Invoke Invoke-WebRequest -Times 0
        }
    }
}
