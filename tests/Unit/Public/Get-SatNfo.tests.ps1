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
            # Set location to TestDrive for download tests
            Push-Location $TestDrive
        }

        AfterAll {
            Pop-Location
        }

        It 'Should save NFO to current directory when -Download specified' {
            $result = Get-SatNfo -ReleaseName 'Test.Release.2023-GROUP' -Download
            $result | Should -BeOfType [System.IO.FileInfo]
            $result.Name | Should -Be 'group.nfo'
            Test-Path $result.FullName | Should -BeTrue
        }

        It 'Should save NFO to specified directory when -Download -OutPath specified' {
            $testDir = Join-Path $TestDrive 'download_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            $result = Get-SatNfo -ReleaseName 'Test.Release.2023-GROUP' -Download -OutPath $testDir
            $result | Should -BeOfType [System.IO.FileInfo]
            $result.DirectoryName | Should -Be $testDir
        }
    }

    Context 'AsString functionality' {
        BeforeAll {
            Mock Invoke-RestMethod { return 'NFO content here' }
        }

        It 'Should return NFO content as string when -AsString specified' {
            $result = Get-SatNfo -ReleaseName 'Test.Release.2023-GROUP' -AsString
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
            { Get-SatNfo -ReleaseName 'Test.Release' -Download -OutPath 'C:\NonExistent\Path\That\Does\Not\Exist' } |
                Should -Throw "*Directory does not exist*"
        }
    }

    Context 'Save to file functionality' {
        BeforeAll {
            Mock Invoke-RestMethod { return 'NFO file content here' }
        }

        It 'Should save NFO to file when -Download -OutPath specified' {
            $testDir = Join-Path $TestDrive 'nfo_test'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            $result = Get-SatNfo -ReleaseName 'Test.Release.2023-GROUP' -Download -OutPath $testDir
            $result | Should -Not -BeNullOrEmpty
            $result.FullName | Should -Match '\.nfo$'
        }

        It 'Should use NFO filename from API response' {
            $testDir = Join-Path $TestDrive 'nfo_test2'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            $result = Get-SatNfo -ReleaseName 'Test.Release.2023-GROUP' -Download -OutPath $testDir
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

            Get-SatNfo -ReleaseName 'Test.Release' -Download -OutPath $testDir
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

            $result = Get-SatNfo -ReleaseName 'Test.Release' -Download -OutPath $testDir
            $result.Name | Should -Be 'Test.Release.nfo'
        }

        It 'Should sanitize invalid characters in filename' {
            Mock Invoke-SatApi {
                return @{
                    nfo     = 'bad/file.nfo'
                    nfolink = 'https://www.srrdb.com/download/file/Test/bad.nfo'
                }
            }

            $testDir = Join-Path $TestDrive 'nfo_test5'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            $result = Get-SatNfo -ReleaseName 'Test.Release' -Download -OutPath $testDir
            # Verify no invalid characters remain using the platform actual invalid chars
            $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
            $invalidPattern = '[' + [regex]::Escape([string]::new($invalidChars)) + ']'
            $result.Name | Should -Not -Match $invalidPattern
        }

        It 'Should handle array response for nfo and nfolink' {
            Mock Invoke-SatApi {
                return @{
                    nfo     = @('first.nfo', 'second.nfo')
                    nfolink = @('https://www.srrdb.com/download/file/Test/first.nfo', 'https://www.srrdb.com/download/file/Test/second.nfo')
                }
            }

            $testDir = Join-Path $TestDrive 'nfo_test6'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            $result = Get-SatNfo -ReleaseName 'Test.Release' -Download -OutPath $testDir
            $result.Name | Should -Be 'first.nfo'
        }

        It 'Should add .nfo extension when filename does not have it' {
            Mock Invoke-SatApi {
                return @{
                    nfo     = 'readme.txt'
                    nfolink = 'https://www.srrdb.com/download/file/Test/readme.txt'
                }
            }

            $testDir = Join-Path $TestDrive 'nfo_test7'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            $result = Get-SatNfo -ReleaseName 'Test.Release' -Download -OutPath $testDir
            $result.Name | Should -Be 'readme.txt.nfo'
        }
    }
}
}
