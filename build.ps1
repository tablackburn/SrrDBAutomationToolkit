# spell-checker:ignore nologo psake
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    'Command',
    Justification = 'false positive'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    'Parameter',
    Justification = 'false positive'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    'CommandAst',
    Justification = 'false positive'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    'FakeBoundParams',
    Justification = 'false positive'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    'Help',
    Justification = 'false positive'
)]
[CmdletBinding(DefaultParameterSetName = 'Task')]
param(
    # Build task(s) to execute
    [Parameter(ParameterSetName = 'task', Position = 0)]
    [ArgumentCompleter( {
            param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
            try {
                Get-PSakeScriptTasks -BuildFile './build.psake.ps1' -ErrorAction 'Stop' |
                Where-Object { $_.Name -like "$WordToComplete*" } |
                Select-Object -ExpandProperty 'Name'
            }
            catch {
                # Silently fail if psake tasks can't be retrieved
                @()
            }
        })]
    [string[]]$Task = 'default',

    # Bootstrap dependencies
    [switch]$Bootstrap,

    # List available build tasks
    [Parameter(ParameterSetName = 'Help')]
    [switch]$Help,

    # Optional properties to pass to psake
    [hashtable]$Properties,

    # Optional parameters to pass to psake
    [hashtable]$Parameters
)

$ErrorActionPreference = 'Stop'

# Define dependency file pattern
$dependencyFilePattern = '*.depend.psd1'
$dependencyFilePath = Join-Path -Path $PSScriptRoot -ChildPath $dependencyFilePattern

# Bootstrap dependencies
if ($Bootstrap) {
    $null = PackageManagement\Get-PackageProvider -Name 'NuGet' -ForceBootstrap
    if ((Test-Path -Path $dependencyFilePath)) {
        # Ensure PSGallery is registered and trusted
        if (-not (Get-PSRepository -Name 'PSGallery' -ErrorAction 'SilentlyContinue')) {
            Register-PSRepository -Default
        }
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'

        if (-not (Get-Module -Name 'PSDepend' -ListAvailable)) {
            Install-Module -Name 'PSDepend' -Scope 'CurrentUser' -Repository 'PSGallery' -Force
        }
        Import-Module -Name 'PSDepend' -Verbose:$false

        # Try to import existing modules first to avoid installation locks
        # Only install if import fails (missing modules or wrong versions)
        $psDependParameters = @{
            Path          = $PSScriptRoot
            Recurse       = $False
            WarningAction = 'SilentlyContinue'
            Import        = $True
            Force         = $True
            ErrorAction   = 'Stop'
        }

        $importSucceeded = $false
        try {
            Invoke-PSDepend @psDependParameters
            $importSucceeded = $true
            Write-Verbose 'Successfully imported existing modules.' -Verbose
        }
        catch {
            Write-Verbose "Could not import all required modules: $_" -Verbose
            Write-Verbose 'Attempting to install missing or outdated dependencies...' -Verbose
        }

        # If import failed, install the dependencies
        if (-not $importSucceeded) {
            try {
                Invoke-PSDepend @psDependParameters -Install
            }
            catch {
                Write-Error "Failed to install and import required dependencies: $_"
                Write-Error 'This may be due to locked module files. Please restart the build environment or clear module locks.'
                if ($_.Exception.InnerException) {
                    Write-Error "Inner exception: $($_.Exception.InnerException.Message)"
                }
                throw
            }
        }
    }
    else {
        Write-Warning "No dependency file ($dependencyFilePattern) found. Skipping build dependency installation."
    }
}
else {
    if (-not (Get-Module -Name 'PSDepend' -ListAvailable)) {
        throw 'Missing dependencies. Please run with the "-Bootstrap" flag to install dependencies.'
    }
    Invoke-PSDepend -Path $PSScriptRoot -Recurse $False -WarningAction 'SilentlyContinue' -Import -Force
}

# Execute psake task(s)
$psakeFile = './build.psake.ps1'
if ($PSCmdlet.ParameterSetName -eq 'Help') {
    Get-PSakeScriptTasks -BuildFile $psakeFile |
    Format-Table -Property 'Name', 'Description', 'Alias', 'DependsOn'
}
else {
    Set-BuildEnvironment -Force
    Invoke-psake -BuildFile $psakeFile -TaskList $Task -NoLogo -Properties $Properties -Parameters $Parameters
    exit ([int](-not $psake.build_success))
}
