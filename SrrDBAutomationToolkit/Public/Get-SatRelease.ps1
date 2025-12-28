function Get-SatRelease {
    <#
    .SYNOPSIS
        Gets detailed information about a specific release from srrDB.

    .DESCRIPTION
        Retrieves comprehensive details about a scene release from the srrDB database,
        including file information, archive details, and metadata.

    .PARAMETER ReleaseName
        The release dirname to look up. This is the exact scene release name.
        Supports pipeline input.

    .EXAMPLE
        Get-SatRelease -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS"

        Gets detailed information about the specified release.

    .EXAMPLE
        Search-SatRelease -Query "Inception" | Get-SatRelease

        Searches for releases and pipes them to get full details.

    .EXAMPLE
        "Inception.2010.1080p.BluRay.x264-SPARKS" | Get-SatRelease

        Gets release details using pipeline input.

    .OUTPUTS
        PSCustomObject with release details including:
        - Name: Release dirname
        - Files: Array of files in the release
        - Archived: Array of archive files
        - ArchivedFiles: Files within archives
        - SrrSize: Size of the SRR file
        - HasNfo: Boolean indicating NFO availability
        - HasSrs: Boolean indicating SRS availability
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Release')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ReleaseName
    )

    process {
        try {
            $encodedRelease = [System.Uri]::EscapeDataString($ReleaseName)
            $endpoint = "/details/$encodedRelease"
            $uri = Join-SatUri -Endpoint $endpoint

            Write-Verbose "Getting release details: $uri"

            $result = Invoke-SatApi -Uri $uri -ErrorAction 'Stop'

            # Check for API errors
            if ($result.error) {
                throw "srrDB API error: $($result.error)"
            }

            # Check if release was found
            if (-not $result.name) {
                Write-Warning "Release not found: $ReleaseName"
                return
            }

            # Build release object
            $releaseObj = [PSCustomObject]@{
                PSTypeName    = 'SrrDBAutomationToolkit.Release'
                Name          = $result.name
                Files         = $result.files
                Archived      = $result.archived
                ArchivedFiles = $result.'archived-files'
                SrrSize       = $result.'srr-size'
                HasNfo        = [bool]($result.hasNFO -eq 'yes' -or $result.nfo)
                HasSrs        = [bool]($result.hasSRS -eq 'yes' -or $result.srs)
            }

            $releaseObj
        }
        catch {
            throw "Failed to get release details for '$ReleaseName': $($_.Exception.Message)"
        }
    }
}
