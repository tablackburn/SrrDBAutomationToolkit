# spell-checker:ignore BHPS juneb_get_help
# Taken with love from @juneb_get_help (https://raw.githubusercontent.com/juneb/PesterTDD/master/Module.Help.Tests.ps1)
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    'commandName',
    Justification = 'false positive'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    'commands',
    Justification = 'false positive'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    'commandParameterNames',
    Justification = 'false positive'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    'helpLinks',
    Justification = 'false positive'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    'helpParameterNames',
    Justification = 'false positive'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    'parameterHelpType',
    Justification = 'false positive'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    'global:CustomTypes',
    Justification = 'Needed for comparison'
)]
param()

BeforeDiscovery {
    function global:FilterOutCommonParameters {
        <#
        .SYNOPSIS
        Returns a list of parameters that are not common parameters.

        .DESCRIPTION
        Compares the parameters of a command to the common parameters and returns a list of parameters that are
        not common parameters.

        .PARAMETER Parameters
        Specifies the parameters of a command.

        .NOTES
        This function will also filter out dynamic parameters and parameters that are not defined explicitly in the command definition.

        .EXAMPLE
        global:FilterOutCommonParameters -Parameters (Get-Command Get-Service).ParameterSets.Parameters

        This example returns a list of parameters that are not common parameters for the Get-Service command.
        #>
        param ($Parameters)
        $commonParameters = [System.Management.Automation.PSCmdlet]::CommonParameters +
            [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
        $Parameters | Where-Object { $_.Name -notin $commonParameters -and $_.IsDynamic -eq $false } | Sort-Object -Property 'Name' -Unique
    }

    <# Check if the BHBuildOutput environment variable exists to determine if this test is running in a psake
    build or not. If it does not exist, it is not running in a psake build, so build the module.
    If the BHBuildOutput environment variable exists, it is running in a psake build, so do not
    build the module. #>
    if ($null -eq $Env:BHBuildOutput) {
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\build.psake.ps1'
        $invokePsakeParameters = @{
            TaskList  = 'Build'
            BuildFile = $buildFilePath
        }
        Invoke-psake @invokePsakeParameters
    }

    # PowerShellBuild outputs to Output/<ModuleName>/<Version>/, override BHBuildOutput
    $projectRoot = Split-Path -Parent $PSScriptRoot
    $sourceManifest = Join-Path $projectRoot "$Env:BHProjectName/$Env:BHProjectName.psd1"
    $moduleVersion = (Import-PowerShellDataFile -Path $sourceManifest).ModuleVersion
    $Env:BHBuildOutput = Join-Path $projectRoot "Output/$Env:BHProjectName/$moduleVersion"

    # Define the path to the module manifest
    $moduleManifestFilename = $Env:BHProjectName + '.psd1'
    $moduleManifestPath = Join-Path -Path $Env:BHBuildOutput -ChildPath $moduleManifestFilename

    $global:CustomTypes = @()
    @(
        'Enums'
        'Classes'
    ) | ForEach-Object {
        $path = Join-Path -Path $Env:BHBuildOutput -ChildPath $_
        if (Test-Path $path) {
            $global:CustomTypes += (Get-ChildItem -Path $path -Recurse -ErrorAction 'SilentlyContinue').BaseName
        }
    }

    # Remove all versions of the module from the session. Pester can't handle multiple versions.
    Get-Module $Env:BHProjectName | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'

    # Get module commands
    $getCommandParameters = @{
        Module      = (Get-Module $Env:BHProjectName)
        CommandType = [System.Management.Automation.CommandTypes[]]'Cmdlet, Function' # Not alias
    }
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        $getCommandParameters.CommandType[0] += 'Workflow'
    }
    $commands = Get-Command @getCommandParameters

    ## When testing help, remember that help is cached at the beginning of each session.
    ## To test, restart session.
}

BeforeAll {
    <# Check if the BHBuildOutput environment variable exists to determine if this test is running in a psake
    build or not. If it does not exist, it is not running in a psake build, so build the module.
    If the BHBuildOutput environment variable exists, it is running in a psake build, so do not
    build the module. #>
    if ($null -eq $Env:BHBuildOutput) {
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\build.psake.ps1'
        $invokePsakeParameters = @{
            TaskList  = 'Build'
            BuildFile = $buildFilePath
        }
        Invoke-psake @invokePsakeParameters
    }
}

Describe "Test help for <_.Name>" -ForEach $commands {

    BeforeDiscovery {
        # Get command help, parameters, and links
        $command               = $_
        $commandHelp           = Get-Help -Name $command.Name -ErrorAction 'SilentlyContinue'
        $commandParameters     = global:FilterOutCommonParameters -Parameters $command.ParameterSets.Parameters
        $commandParameterNames = $commandParameters.Name
        $helpLinks             = $commandHelp.relatedLinks.navigationLink.uri | Where-Object { $_ -match '^https?://' }
    }

    BeforeAll {
        # These variables are needed in both discovery and test phases so we need to duplicate them here
        $command                = $_
        $commandName            = $_.Name
        $commandHelp            = Get-Help -Name $command.Name -ErrorAction 'SilentlyContinue'
        $commandParameters      = global:FilterOutCommonParameters -Parameters $command.ParameterSets.Parameters
        $commandParameterNames  = $commandParameters.Name
        $helpParameters         = global:FilterOutCommonParameters -Parameters $commandHelp.Parameters.Parameter
        $helpParameterNames     = $helpParameters.Name
    }

    # If help is not found, synopsis in auto-generated help is the syntax diagram
    It 'Help is not auto-generated' {
        $commandHelp.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'Has description' {
        $commandHelp.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one example
    It 'Has example code' {
        ($commandHelp.Examples.Example | Select-Object -First 1).Code | Should -Not -BeNullOrEmpty
    }

    # Should be at least one example description
    It 'Has example help' {
        ($commandHelp.Examples.Example.Remarks | Select-Object -First 1).Text | Should -Not -BeNullOrEmpty
    }

    It 'Help link <_> is valid' -ForEach $helpLinks {
        $currentProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        $invokeWebRequestParameters = @{
            Uri             = $_
            UseBasicParsing = $true
            ErrorAction     = 'Continue'
        }
        $invokeWebRequestResult = Invoke-WebRequest @invokeWebRequestParameters
        $ProgressPreference = $currentProgressPreference
        $statusCode = $invokeWebRequestResult.StatusCode
        $statusCode | Should -Be '200'
    }

    Context 'Parameter <_.Name>' -Foreach $commandParameters {

        BeforeAll {
            $parameter         = $_
            $parameterName     = $parameter.Name
            $parameterHelp     = $commandHelp.parameters.parameter | Where-Object { $_.Name -eq $parameterName }
            $parameterHelpType = if ($parameterHelp.type.name) { $parameterHelp.type.name }
        }

        # Should be a description for every parameter
        It 'Has description' {
            $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
        }

        # Required value in Help should match IsMandatory property of parameter
        It 'Has correct [mandatory] value' {
            $codeMandatory = $_.IsMandatory.toString()
            $parameterHelp.Required | Should -Be $codeMandatory
        }

        # Parameter type in help should match code
        It 'Has correct parameter type' {
            # Handle array of custom types by removing [] from end
            $typeName = ($parameter.ParameterType.Name).TrimEnd('[]')
            if ($typeName -in $global:CustomTypes) {
                # Skip custom enums or classes. They won't show up in the help.
            }
            else {
                $parameterHelpType | Should -Be $parameter.ParameterType.Name
            }
        }
    }

    Context 'Test <_> help parameter help for <commandName>' -Foreach $helpParameterNames {

        # Shouldn't find extra parameters in help
        It 'finds help parameter in code: <_>' {
            $_ -in $parameterNames | Should -Be $true
        }
    }
}
