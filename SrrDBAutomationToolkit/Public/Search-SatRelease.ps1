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

    .PARAMETER Foreign
        If specified, only return foreign (non-English) releases.

    .PARAMETER Confirmed
        If specified, only return confirmed releases.

    .PARAMETER RarHash
        Filter by RAR file hash.

    .PARAMETER ArchiveCrc
        Filter by archive CRC value.

    .PARAMETER ArchiveSize
        Filter by archive size in bytes.

    .PARAMETER InternetSubtitlesDbHash
        Filter by Internet Subtitles Database (ISDb) hash.

    .PARAMETER Compressed
        If specified, only return compressed releases.

    .PARAMETER Order
        Sort order for results. Valid values:
        date-asc, date-desc, release-asc, release-desc

    .PARAMETER Country
        Filter by country code (e.g., US, UK, DE).

    .PARAMETER Language
        Filter by language (e.g., English, German, French).

    .PARAMETER SampleFilename
        Filter by sample filename stored inside SRS (Sample Rescue Service) files.

    .PARAMETER SampleCrc
        Filter by CRC32 of the sample video stored inside SRS files.

    .PARAMETER MaxResults
        Maximum number of results to return. Default is all matching results.
        The function automatically paginates through all available results.

    .EXAMPLE
        Search-SatRelease -Query "Harry Potter"

        Searches for releases containing "Harry" and "Potter" in the name.
        Automatically fetches all matching results across multiple API pages.

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
        [switch]
        $Foreign,

        [Parameter(Mandatory = $false)]
        [switch]
        $Confirmed,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $RarHash,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ArchiveCrc,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, [long]::MaxValue)]
        [long]
        $ArchiveSize,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InternetSubtitlesDbHash,

        [Parameter(Mandatory = $false)]
        [switch]
        $Compressed,

        [Parameter(Mandatory = $false)]
        [ValidateSet('date-asc', 'date-desc', 'release-asc', 'release-desc')]
        [string]
        $Order,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Country,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Language,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SampleFilename,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SampleCrc,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $MaxResults
    )

    try {
        # Build base search query parameters (without skip)
        $searchQueryParameters = @{}

        if ($Query) {
            $searchQueryParameters['Query'] = $Query
        }
        if ($ReleaseName) {
            $searchQueryParameters['ReleaseName'] = $ReleaseName
        }
        if ($Group) {
            $searchQueryParameters['Group'] = $Group
        }
        if ($Category) {
            $searchQueryParameters['Category'] = $Category
        }
        if ($ImdbId) {
            $searchQueryParameters['ImdbId'] = $ImdbId
        }
        if ($HasNfo) {
            $searchQueryParameters['HasNfo'] = $true
        }
        if ($HasSrs) {
            $searchQueryParameters['HasSrs'] = $true
        }
        if ($Date) {
            $searchQueryParameters['Date'] = $Date
        }
        if ($Foreign) {
            $searchQueryParameters['Foreign'] = $true
        }
        if ($Confirmed) {
            $searchQueryParameters['Confirmed'] = $true
        }
        if ($RarHash) {
            $searchQueryParameters['RarHash'] = $RarHash
        }
        if ($ArchiveCrc) {
            $searchQueryParameters['ArchiveCrc'] = $ArchiveCrc
        }
        if ($PSBoundParameters.ContainsKey('ArchiveSize')) {
            $searchQueryParameters['ArchiveSize'] = $ArchiveSize
        }
        if ($InternetSubtitlesDbHash) {
            $searchQueryParameters['InternetSubtitlesDbHash'] = $InternetSubtitlesDbHash
        }
        if ($Compressed) {
            $searchQueryParameters['Compressed'] = $true
        }
        if ($Order) {
            $searchQueryParameters['Order'] = $Order
        }
        if ($Country) {
            $searchQueryParameters['Country'] = $Country
        }
        if ($Language) {
            $searchQueryParameters['Language'] = $Language
        }
        if ($SampleFilename) {
            $searchQueryParameters['SampleFilename'] = $SampleFilename
        }
        if ($SampleCrc) {
            $searchQueryParameters['SampleCrc'] = $SampleCrc
        }

        $baseSearchPath = ConvertTo-SatSearchQuery @searchQueryParameters

        if (-not $baseSearchPath) {
            throw "No search criteria specified. Please provide at least a Query or ReleaseName."
        }

        # Pagination variables
        $pageSize = 45
        $skip = 0
        $totalReturned = 0
        $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()

        do {
            # Build search path with skip for pagination
            if ($skip -gt 0) {
                $searchPath = "$baseSearchPath/skip:$skip"
            }
            else {
                $searchPath = $baseSearchPath
            }

            $endpoint = "/search/$searchPath"
            $uri = Join-SatUri -Endpoint $endpoint

            Write-Verbose "Searching srrDB: $uri"

            $result = Invoke-SatApi -Uri $uri -ErrorAction 'Stop'

            # Check for API errors
            if ($result.error) {
                throw "srrDB API error: $($result.error)"
            }

            # Process page results
            $hitMaxResults = $false
            if ($result.results -and $result.results.Count -gt 0) {
                foreach ($item in $result.results) {
                    # Check if we've hit MaxResults before adding
                    if ($MaxResults -and $allResults.Count -ge $MaxResults) {
                        $hitMaxResults = $true
                        break
                    }

                    $releaseObj = [PSCustomObject]@{
                        PSTypeName = 'SrrDBAutomationToolkit.SearchResult'
                        Release    = $item.release
                        Date       = $item.date
                        HasNfo     = [bool]($item.hasNFO -eq 'yes')
                        HasSrs     = [bool]($item.hasSRS -eq 'yes')
                    }
                    $allResults.Add($releaseObj)
                }

                $totalReturned = $result.results.Count
                $skip += $pageSize

                Write-Verbose "Retrieved $($allResults.Count) of $($result.resultsCount) total results"
            }
            else {
                $totalReturned = 0
            }

            # Continue if: we got a full page, haven't hit MaxResults, and there are more results
            $shouldContinue = -not $hitMaxResults -and
                              $totalReturned -eq $pageSize -and
                              $allResults.Count -lt $result.resultsCount
        } while ($shouldContinue)

        if ($allResults.Count -gt 0) {
            $allResults
        }
        else {
            Write-Verbose "No results found for the search query."
        }
    }
    catch {
        $errorRecord = $_
        throw "Failed to search srrDB: $($errorRecord.Exception.Message)"
    }
}
