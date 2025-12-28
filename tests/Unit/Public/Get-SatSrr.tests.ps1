BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'SrrDBAutomationToolkit'

    # Import required functions
    . (Join-Path $ModuleRoot 'Public\Get-SatSrr.ps1')
}

Describe 'Get-SatSrr' {
    BeforeAll {
        Mock Invoke-WebRequest { }
        Mock Get-Item { return [PSCustomObject]@{ FullName = 'C:\Test\release.srr' } }
    }

    Context 'Download functionality' {
        It 'Should call Invoke-WebRequest with correct URL' {
            Get-SatSrr -ReleaseName 'Test.Release-GROUP' -OutPath 'TestDrive:' -Confirm:$false
            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $Uri -match 'srrdb\.com/download/srr/Test\.Release-GROUP'
            }
        }

        It 'Should use correct output filename' {
            Get-SatSrr -ReleaseName 'Test.Release-GROUP' -OutPath 'TestDrive:' -Confirm:$false
            Should -Invoke Invoke-WebRequest -ParameterFilter {
                $OutFile -match 'Test\.Release-GROUP\.srr'
            }
        }
    }

    Context 'PassThru parameter' {
        It 'Should return FileInfo when PassThru is specified' {
            $result = Get-SatSrr -ReleaseName 'Test.Release-GROUP' -OutPath 'TestDrive:' -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return nothing by default' {
            $result = Get-SatSrr -ReleaseName 'Test.Release-GROUP' -OutPath 'TestDrive:' -Confirm:$false
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Pipeline support' {
        It 'Should accept pipeline input' {
            'Test.Release-GROUP' | Get-SatSrr -OutPath 'TestDrive:' -Confirm:$false
            Should -Invoke Invoke-WebRequest
        }

        It 'Should accept Release property from pipeline' {
            $searchResult = [PSCustomObject]@{ Release = 'Test.Release-GROUP' }
            $searchResult | Get-SatSrr -OutPath 'TestDrive:' -Confirm:$false
            Should -Invoke Invoke-WebRequest
        }
    }

    Context 'ShouldProcess support' {
        It 'Should support WhatIf' {
            Get-SatSrr -ReleaseName 'Test.Release-GROUP' -OutPath 'TestDrive:' -WhatIf
            Should -Not -Invoke Invoke-WebRequest
        }
    }

    Context 'Error handling' {
        It 'Should throw on download failure' {
            Mock Invoke-WebRequest { throw "Download failed" }
            { Get-SatSrr -ReleaseName 'Test.Release-GROUP' -OutPath 'TestDrive:' -Confirm:$false } |
                Should -Throw "*Failed to download SRR*"
        }

        It 'Should throw when OutPath directory does not exist' {
            { Get-SatSrr -ReleaseName 'Test.Release' -OutPath 'C:\NonExistent\Path\That\Does\Not\Exist' } |
                Should -Throw "*Directory does not exist*"
        }
    }
}
