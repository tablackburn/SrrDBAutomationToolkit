function Get-SatImdb {
    <#
    .SYNOPSIS
        Gets IMDB information linked to a release from srrDB.

    .DESCRIPTION
        Retrieves IMDB metadata associated with a scene release, including
        title, year, rating, and other movie/show information.

    .PARAMETER ReleaseName
        The release dirname to look up. This is the exact scene release name.
        Supports pipeline input.

    .EXAMPLE
        Get-SatImdb -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS"

        Gets IMDB information linked to the specified release.

    .EXAMPLE
        Search-SatRelease -Query "Inception" | Get-SatImdb

        Searches for releases and gets their IMDB information.

    .EXAMPLE
        "Inception.2010.1080p.BluRay.x264-SPARKS" | Get-SatImdb

        Gets IMDB info using pipeline input.

    .OUTPUTS
        PSCustomObject with properties:
        - Release: Release dirname
        - ImdbId: IMDB ID (e.g., tt1375666)
        - Title: Movie/show title
        - Year: Release year
        - Rating: IMDB rating
        - Votes: Number of votes
        - Genre: Genre(s)
        - Director: Director name(s)
        - Actors: Actor names
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
            $endpoint = "/imdb/$encodedRelease"
            $uri = Join-SatUri -Endpoint $endpoint

            Write-Verbose "Getting IMDB info: $uri"

            $result = Invoke-SatApi -Uri $uri -ErrorAction 'Stop'

            # Check for API errors
            if ($result.error) {
                throw "srrDB API error: $($result.error)"
            }

            # Check if IMDB info was found
            if (-not $result.imdbID -and -not $result.imdb) {
                Write-Warning "No IMDB information found for release: $ReleaseName"
                return
            }

            # Build IMDB info object
            $imdbObject = [PSCustomObject]@{
                PSTypeName = 'SrrDBAutomationToolkit.ImdbInfo'
                Release    = $ReleaseName
                ImdbId     = $result.imdbID
                Title      = $result.title
                Year       = $result.year
                Rating     = $result.rating
                Votes      = $result.votes
                Genre      = $result.genre
                Director   = $result.director
                Actors     = $result.actors
            }

            $imdbObject
        }
        catch {
            $errorRecord = $_
            throw "Failed to get IMDB info for '$ReleaseName': $($errorRecord.Exception.Message)"
        }
    }
}
