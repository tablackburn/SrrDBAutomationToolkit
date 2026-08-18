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
    [ValidateNotNullOrEmpty()]
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
        # Ensure PSGallery is registered and trusted.
        #
        # Register-PSRepository -Default shells out to nuget.exe, which on some Windows
        # runner images fails with:
        #
        #   NuGet.Commands.CommandException: Missing option value for: '-source'
        #
        # That leaves PSGallery unregistered, and the Set-PSRepository call that used to
        # follow it unconditionally then died with "No repository with the name
        # 'PSGallery' was found", masking the real cause. Fall back to registering the
        # gallery explicitly by URL, and only configure it once it actually exists.
        $psGallery = Get-PSRepository -Name 'PSGallery' -ErrorAction 'SilentlyContinue'
        if (-not $psGallery) {
            try {
                Register-PSRepository -Default -ErrorAction 'Stop'
            }
            catch {
                Write-Verbose "Register-PSRepository -Default failed ($($_.Exception.Message)); registering PSGallery explicitly." -Verbose
            }

            $psGallery = Get-PSRepository -Name 'PSGallery' -ErrorAction 'SilentlyContinue'
            if (-not $psGallery) {
                $registerParameters = @{
                    Name               = 'PSGallery'
                    SourceLocation     = 'https://www.powershellgallery.com/api/v2'
                    InstallationPolicy = 'Trusted'
                    ErrorAction        = 'Stop'
                }
                Register-PSRepository @registerParameters
                $psGallery = Get-PSRepository -Name 'PSGallery' -ErrorAction 'SilentlyContinue'
            }
        }

        if (-not $psGallery) {
            throw 'Could not register the PSGallery repository; build dependencies cannot be installed.'
        }

        # A repository named PSGallery is not necessarily the PowerShell Gallery. If one
        # is already registered against a different SourceLocation, every dependency in
        # build.depend.psd1 would be installed from it on the strength of the name alone.
        #
        # Compare the parsed URI's scheme, host and port rather than the string:
        #
        #   - String equality with -ne is case-insensitive, so a differently cased value
        #     slipped through. Switching to -cne would be wrong in the other direction,
        #     since host names are case-insensitive by definition and -cne would reject
        #     https://WWW.PowerShellGallery.com/api/v2, which is the real gallery.
        #   - Port matters: a non-default port on the same name reaches a different
        #     listener. [Uri] supplies 443 for https when none is given, so the canonical
        #     URL and an explicit :443 both match, while :444 does not.
        #   - The path is deliberately not compared. The gallery serves both /api/v2 and
        #     /api/v3, and any path on the genuine host is still the genuine host. Host
        #     and port are the trust boundary; pinning the path would only add a false
        #     rejection for a legitimate registration.
        $expectedSource = [Uri]'https://www.powershellgallery.com/api/v2'
        $actualSource = $psGallery.SourceLocation -as [Uri]
        $sourceIsExpected = $null -ne $actualSource -and
            $actualSource.Scheme -eq $expectedSource.Scheme -and
            $actualSource.Host -eq $expectedSource.Host -and
            $actualSource.Port -eq $expectedSource.Port
        if (-not $sourceIsExpected) {
            $expectedAuthority = '{0}://{1}:{2}' -f $expectedSource.Scheme, $expectedSource.Host, $expectedSource.Port
            throw "The repository named 'PSGallery' points at [$($psGallery.SourceLocation)], which is not $expectedAuthority. Refusing to install build dependencies from an unexpected source."
        }

        if ($psGallery.InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'
        }

        if (-not (Get-Module -Name 'PSDepend' -ListAvailable)) {
            Install-Module -Name 'PSDepend' -Scope 'CurrentUser' -Repository 'PSGallery' -Force
        }
        Import-Module -Name 'PSDepend' -Verbose:$false

        $psDependParameters = @{
            Path          = $PSScriptRoot
            Recurse       = $False
            WarningAction = 'SilentlyContinue'
            Force         = $True
            ErrorAction   = 'Stop'
        }

        # Install before importing, never the other way round.
        #
        # This used to attempt an import first and only install if that failed, to avoid
        # installation locks. That is safe on a warm cache, where the requested versions
        # are already present, but wrong on a cold one: the import pass loads whatever
        # version happens to be on the machine already -- typically an older Pester from
        # the runner image -- and Pester ships a binary Pester.dll that cannot then be
        # replaced in-process by the version the subsequent install brings in:
        #
        #   An incompatible version of the Pester.dll assembly is already loaded.
        #   The loaded dll version is 5.9.0.0, but at least version 6.1.0 is required
        #
        # -Test reports whether each dependency is already satisfied without importing
        # anything, so it is safe to run before anything is loaded (measured at ~6s here).
        # Gate the install on it so a satisfied machine does no install work at all --
        # -Install carries -Force, which re-resolves and re-downloads every dependency.
        $dependenciesSatisfied = $false
        try {
            $testResults = @(Invoke-PSDepend @psDependParameters -Test -Quiet)
            $dependenciesSatisfied = $testResults.Count -gt 0 -and $testResults -notcontains $false
        }
        catch {
            Write-Verbose "Could not determine dependency status: $_" -Verbose
        }

        if (-not $dependenciesSatisfied) {
            Write-Verbose 'Installing missing or outdated dependencies...' -Verbose
            try {
                Invoke-PSDepend @psDependParameters -Install
            }
            catch {
                # Compose one message and throw it, rather than emitting several
                # Write-Error calls: $ErrorActionPreference is 'Stop' in this script, so
                # the first Write-Error terminates and every diagnostic after it -- the
                # lock hint, the inner exception -- is silently dropped.
                $installError = "Failed to install required dependencies: $($_.Exception.Message)"
                if ($_.Exception.InnerException) {
                    $installError += " Inner exception: $($_.Exception.InnerException.Message)"
                }
                $installError += ' This may be due to locked module files; restart the build environment or clear module locks.'
                throw $installError
            }
        }

        try {
            Invoke-PSDepend @psDependParameters -Import
            Write-Verbose 'Successfully imported required modules.' -Verbose
        }
        catch {
            # Single composed throw -- see the note in the install catch above.
            $importError = "Failed to import required dependencies: $($_.Exception.Message)"
            if ($_.Exception.InnerException) {
                $importError += " Inner exception: $($_.Exception.InnerException.Message)"
            }
            throw $importError
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
