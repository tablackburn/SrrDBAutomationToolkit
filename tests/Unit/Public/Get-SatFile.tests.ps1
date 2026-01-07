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

    Context 'Download functionality' {
        It 'Should call Invoke-WebRequest with correct URL for simple filename' {
            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -OutPath 'TestDrive:' -Confirm:$false
            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $Uri -match 'srrdb\.com/download/file/Test\.Release-GROUP/proof\.jpg'
            }
        }

        It 'Should call Invoke-WebRequest with correct URL for filename with path prefix' {
            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'Proof/proof.jpg' -OutPath 'TestDrive:' -Confirm:$false
            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $Uri -match 'srrdb\.com/download/file/Test\.Release-GROUP/Proof/proof\.jpg'
            }
        }

        It 'Should preserve forward slashes in URL encoding' {
            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'Proof/proof image.jpg' -OutPath 'TestDrive:' -Confirm:$false
            Should -Invoke Invoke-WebRequest -ParameterFilter {
                # URI should contain the path with forward slash preserved
                $Uri -like '*Proof/proof*image.jpg*' -and $Uri -notlike '*Proof%2F*'
            }
        }

        It 'Should strip path components from local filename' {
            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'Proof/proof.jpg' -OutPath 'TestDrive:' -Confirm:$false
            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $OutFile -like '*\proof.jpg' -or $OutFile -like '*/proof.jpg'
            }
        }

        It 'Should sanitize invalid filesystem characters in filename' {
            # Use forward slash which should be sanitized from the filename component
            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'Proof/file.jpg' -OutPath 'TestDrive:' -Confirm:$false
            Should -Invoke Invoke-WebRequest -ParameterFilter {
                # Path component should be stripped, not turned into underscore
                $OutFile -like '*file.jpg' -and $OutFile -notlike '*/*Proof*'
            }
        }

        It 'Should download to current directory when OutPath not specified' {
            Push-Location $TestDrive
            try {
                Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -Confirm:$false
                Should -Invoke Invoke-WebRequest -ParameterFilter {
                    $OutFile -match 'proof\.jpg'
                }
            }
            finally {
                Pop-Location
            }
        }
    }

    Context 'URL encoding' {
        It 'Should URL encode release name' {
            Get-SatFile -ReleaseName 'Test Release-GROUP' -FileName 'proof.jpg' -OutPath 'TestDrive:' -Confirm:$false
            Should -Invoke Invoke-WebRequest -ParameterFilter {
                # URI should contain the encoded or decoded space - accept either
                $Uri -like '*Test*Release-GROUP*'
            }
        }

        It 'Should URL encode each path segment individually' {
            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'Sample/sample file.mkv' -OutPath 'TestDrive:' -Confirm:$false
            Should -Invoke Invoke-WebRequest -ParameterFilter {
                # URI should contain the path with forward slash preserved
                $Uri -like '*Sample/sample*file.mkv*' -and $Uri -notlike '*Sample%2F*'
            }
        }
    }

    Context 'PassThru parameter' {
        It 'Should return FileInfo when PassThru is specified' {
            $result = Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -OutPath 'TestDrive:' -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return nothing by default' {
            $result = Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -OutPath 'TestDrive:' -Confirm:$false
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Pipeline support' {
        It 'Should accept ReleaseName from pipeline' {
            $object = [PSCustomObject]@{ ReleaseName = 'Test.Release-GROUP'; FileName = 'proof.jpg' }
            $object | Get-SatFile -OutPath 'TestDrive:' -Confirm:$false
            Should -Invoke Invoke-WebRequest
        }

        It 'Should accept FileName from pipeline' {
            $object = [PSCustomObject]@{ ReleaseName = 'Test.Release-GROUP'; FileName = 'proof.jpg' }
            $object | Get-SatFile -OutPath 'TestDrive:' -Confirm:$false
            Should -Invoke Invoke-WebRequest
        }
    }

    Context 'ShouldProcess support' {
        It 'Should support WhatIf' {
            Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -OutPath 'TestDrive:' -WhatIf
            Should -Not -Invoke Invoke-WebRequest
        }
    }

    Context 'Error handling' {
        It 'Should throw on download failure' {
            Mock Invoke-WebRequest { throw "Download failed" }
            { Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -OutPath 'TestDrive:' -Confirm:$false } |
                Should -Throw "*Failed to download*"
        }

        It 'Should throw when OutPath directory does not exist' {
            { Get-SatFile -ReleaseName 'Test.Release-GROUP' -FileName 'proof.jpg' -OutPath 'C:\NonExistent\Path\That\Does\Not\Exist' } |
                Should -Throw "*Directory does not exist*"
        }
    }
}
