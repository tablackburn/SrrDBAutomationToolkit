BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'SrrDBAutomationToolkit'

    # Import required functions
    . (Join-Path $ModuleRoot 'Private\Invoke-SatApi.ps1')
    . (Join-Path $ModuleRoot 'Private\Join-SatUri.ps1')
    . (Join-Path $ModuleRoot 'Public\Get-SatNfo.ps1')
}

Describe 'Get-SatNfo' {
    BeforeAll {
        Mock Invoke-SatApi {
            return @{
                nfo     = 'group.nfo'
                nfolink = 'https://www.srrdb.com/download/file/Test.Release/group.nfo'
            }
        }
    }

    Context 'Info retrieval' {
        It 'Should return NFO info' {
            $result = Get-SatNfo -ReleaseName 'Test.Release.2023-GROUP'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return object with correct properties' {
            $result = Get-SatNfo -ReleaseName 'Test.Release.2023-GROUP'
            $result.Release | Should -Be 'Test.Release.2023-GROUP'
            $result.NfoFile | Should -Be 'group.nfo'
            $result.DownloadUrl | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Download functionality' {
        BeforeAll {
            Mock Invoke-RestMethod { return 'NFO content here' }
        }

        It 'Should download NFO content when -Download specified' {
            $result = Get-SatNfo -ReleaseName 'Test.Release.2023-GROUP' -Download
            $result | Should -Be 'NFO content here'
        }
    }

    Context 'Pipeline support' {
        It 'Should accept pipeline input' {
            $result = 'Test.Release.2023-GROUP' | Get-SatNfo
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should accept Release property from pipeline' {
            $searchResult = [PSCustomObject]@{ Release = 'Test.Release.2023-GROUP' }
            $result = $searchResult | Get-SatNfo
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error handling' {
        It 'Should throw on API error response' {
            Mock Invoke-SatApi { return @{ error = 'Not found' } }
            { Get-SatNfo -ReleaseName 'NonExistent' } | Should -Throw "*srrDB API error*"
        }

        It 'Should warn when no NFO found' {
            Mock Invoke-SatApi { return @{ nfo = $null; nfolink = $null } }
            $result = Get-SatNfo -ReleaseName 'NoNfo.Release' -WarningVariable warnings -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'Should throw when OutPath directory does not exist' {
            { Get-SatNfo -ReleaseName 'Test.Release' -OutPath 'C:\NonExistent\Path\That\Does\Not\Exist' } |
                Should -Throw "*Directory does not exist*"
        }
    }

    Context 'Save to file functionality' {
        BeforeAll {
            Mock Invoke-RestMethod { return 'NFO file content here' }
        }

        It 'Should save NFO to file when OutPath specified' {
            $testDir = Join-Path $TestDrive 'nfo_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            $result = Get-SatNfo -ReleaseName 'Test.Release.2023-GROUP' -OutPath $testDir
            $result | Should -Not -BeNullOrEmpty
            $result.FullName | Should -Match '\.nfo$'
        }

        It 'Should use NFO filename from API response' {
            $testDir = Join-Path $TestDrive 'nfo_test2'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            $result = Get-SatNfo -ReleaseName 'Test.Release.2023-GROUP' -OutPath $testDir
            $result.Name | Should -Be 'group.nfo'
        }

        It 'Should construct download URL when nfolink not provided' {
            Mock Invoke-SatApi {
                return @{
                    nfo     = 'custom.nfo'
                    nfolink = $null
                }
            }

            $testDir = Join-Path $TestDrive 'nfo_test3'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            Get-SatNfo -ReleaseName 'Test.Release' -OutPath $testDir
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -match 'srrdb\.com/download/file/Test\.Release/custom\.nfo'
            }
        }

        It 'Should use release name as filename when nfo not provided' {
            Mock Invoke-SatApi {
                return @{
                    nfo     = $null
                    nfolink = 'https://www.srrdb.com/download/file/Test.Release/test.nfo'
                }
            }

            $testDir = Join-Path $TestDrive 'nfo_test4'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            $result = Get-SatNfo -ReleaseName 'Test.Release' -OutPath $testDir
            $result.Name | Should -Be 'Test.Release.nfo'
        }

        It 'Should sanitize invalid characters in filename' {
            Mock Invoke-SatApi {
                return @{
                    nfo     = 'bad:file*name?.nfo'
                    nfolink = 'https://www.srrdb.com/download/file/Test/bad.nfo'
                }
            }

            $testDir = Join-Path $TestDrive 'nfo_test5'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            $result = Get-SatNfo -ReleaseName 'Test.Release' -OutPath $testDir
            $result.Name | Should -Not -Match '[:\\*\\?"<>|]'
        }
    }
}
