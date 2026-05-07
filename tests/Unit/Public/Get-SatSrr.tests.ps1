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

        It 'Should download to current directory when OutPath not specified' {
            Push-Location $TestDrive
            try {
                Get-SatSrr -ReleaseName 'Test.Release-GROUP' -Confirm:$false
                Should -Invoke Invoke-WebRequest -ParameterFilter {
                    $OutFile -match 'Test\.Release-GROUP\.srr'
                }
            }
            finally {
                Pop-Location
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
}
