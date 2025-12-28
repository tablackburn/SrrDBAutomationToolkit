function Search-SatRelease {
    <#
    .SYNOPSIS
        Searches for releases in the srrDB database.

    .DESCRIPTION
        Searches the srrDB scene release database using various filters and criteria.
        Returns matching releases with basic information including release name,
        date, and availability of NFO/SRS files.

    .PARAMETER Query
        Free-text search terms. Searches across release names.

    .PARAMETER ReleaseName
        Exact release name to search for. Uses the faster r: prefix internally
        for direct lookups.

    .PARAMETER Group
        Filter results to a specific release group.

    .PARAMETER Category
        Filter by release category. Valid values include:
        tv, xvid, x264, dvdr, xxx, pc, mac, linux, psx, ps2, ps3, ps4, ps5,
        psp, psv, xbox, xbox360, xboxone, gc, wii, wiiu, switch, nds, 3ds,
        music, mvid, mdvdr, ebook, audiobook, flac, mp3, games, apps, dox

    .PARAMETER ImdbId
        Filter by IMDB ID. Can include or exclude the 'tt' prefix.

    .PARAMETER HasNfo
        If specified, only return releases that have NFO files.

    .PARAMETER HasSrs
        If specified, only return releases that have SRS (Sample Rescue Service) files.

    .PARAMETER Date
        Filter by the date the release was added to the database.
        Format: YYYY-MM-DD

    .PARAMETER Skip
        Number of results to skip for pagination. Use this to fetch subsequent pages
        of results. The API returns 45 results per page.

    .PARAMETER MaxResults
        Maximum number of results to return (1-500). Default is all results from the
        current page.

    .EXAMPLE
        Search-SatRelease -Query "Harry Potter"

        Searches for releases containing "Harry" and "Potter" in the name.

    .EXAMPLE
        Search-SatRelease -Query "Matrix" -Skip 100

        Searches for "Matrix" releases, skipping the first 100 results (page 2+).

    .EXAMPLE
        Search-SatRelease -Query "Inception" -Category "x264" -HasNfo

        Searches for x264 releases of "Inception" that have NFO files.

    .EXAMPLE
        Search-SatRelease -Group "SPARKS" -Category "xvid"

        Finds all xvid releases from the SPARKS group.

    .EXAMPLE
        Search-SatRelease -ImdbId "tt1375666"

        Searches for all releases linked to IMDB ID tt1375666 (Inception).

    .EXAMPLE
        Search-SatRelease -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS"

        Performs a fast exact-match lookup for the specified release name.

    .OUTPUTS
        PSCustomObject with properties:
        - Release: The release dirname
        - Date: Date added to database
        - HasNfo: Boolean indicating NFO availability
        - HasSrs: Boolean indicating SRS availability
    #>
    [CmdletBinding(DefaultParameterSetName = 'Query')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Query', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Query,

        [Parameter(Mandatory = $true, ParameterSetName = 'ReleaseName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ReleaseName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Group,

        [Parameter(Mandatory = $false)]
        [ValidateSet('tv', 'xvid', 'x264', 'dvdr', 'xxx', 'pc', 'mac', 'linux', 'psx', 'ps2', 'ps3', 'ps4', 'ps5',
                     'psp', 'psv', 'xbox', 'xbox360', 'xboxone', 'gc', 'wii', 'wiiu', 'switch', 'nds', '3ds',
                     'music', 'mvid', 'mdvdr', 'ebook', 'audiobook', 'flac', 'mp3', 'games', 'apps', 'dox')]
        [string]
        $Category,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ImdbId,

        [Parameter(Mandatory = $false)]
        [switch]
        $HasNfo,

        [Parameter(Mandatory = $false)]
        [switch]
        $HasSrs,

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
        [string]
        $Date,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $Skip,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 500)]
        [int]
        $MaxResults
    )

    try {
        # Build search query path
        $searchQueryParams = @{}

        if ($Query) {
            $searchQueryParams['Query'] = $Query
        }
        if ($ReleaseName) {
            $searchQueryParams['ReleaseName'] = $ReleaseName
        }
        if ($Group) {
            $searchQueryParams['Group'] = $Group
        }
        if ($Category) {
            $searchQueryParams['Category'] = $Category
        }
        if ($ImdbId) {
            $searchQueryParams['ImdbId'] = $ImdbId
        }
        if ($HasNfo) {
            $searchQueryParams['HasNfo'] = $true
        }
        if ($HasSrs) {
            $searchQueryParams['HasSrs'] = $true
        }
        if ($Date) {
            $searchQueryParams['Date'] = $Date
        }
        if ($PSBoundParameters.ContainsKey('Skip')) {
            $searchQueryParams['Skip'] = $Skip
        }

        $searchPath = ConvertTo-SatSearchQuery @searchQueryParams

        if (-not $searchPath) {
            throw "No search criteria specified. Please provide at least a Query or ReleaseName."
        }

        $endpoint = "/search/$searchPath"
        $uri = Join-SatUri -Endpoint $endpoint

        Write-Verbose "Searching srrDB: $uri"

        $result = Invoke-SatApi -Uri $uri -ErrorAction 'Stop'

        # Check for API errors
        if ($result.error) {
            throw "srrDB API error: $($result.error)"
        }

        # Process search results
        if ($result.results -and $result.results.Count -gt 0) {
            $releases = @()

            foreach ($item in $result.results) {
                $releaseObj = [PSCustomObject]@{
                    PSTypeName = 'SrrDBAutomationToolkit.SearchResult'
                    Release    = $item.release
                    Date       = $item.date
                    HasNfo     = [bool]($item.hasNFO -eq 'yes')
                    HasSrs     = [bool]($item.hasSRS -eq 'yes')
                }
                $releases += $releaseObj
            }

            # Apply MaxResults if specified
            if ($MaxResults -and $releases.Count -gt $MaxResults) {
                $releases = $releases | Select-Object -First $MaxResults
            }

            $releases
        }
        else {
            Write-Verbose "No results found for the search query."
        }
    }
    catch {
        throw "Failed to search srrDB: $($_.Exception.Message)"
    }
}
