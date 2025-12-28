function ConvertTo-SatSearchQuery {
    <#
    .SYNOPSIS
        Converts search parameters to srrDB search path format.

    .DESCRIPTION
        Converts PowerShell parameters into the srrDB API search path format.
        The srrDB API uses a path-based search syntax where filters are appended
        as path segments (e.g., /search/term/category:xvid/nfo:yes).

    .PARAMETER Query
        Free-text search terms. Multiple words are joined with slashes.

    .PARAMETER ReleaseName
        Exact release name to search for (uses r: prefix for faster lookup).

    .PARAMETER Group
        Filter by release group name.

    .PARAMETER Category
        Filter by category (xvid, x264, dvdr, tv, xxx, pc, etc.)

    .PARAMETER ImdbId
        Filter by IMDB ID (with or without tt prefix).

    .PARAMETER HasNfo
        If specified, filter to releases that have NFO files.

    .PARAMETER HasSrs
        If specified, filter to releases that have SRS files.

    .PARAMETER Date
        Filter by date added (format: YYYY-MM-DD).

    .PARAMETER MaxResults
        Maximum number of results to return (used with skip parameter).

    .EXAMPLE
        ConvertTo-SatSearchQuery -Query "Harry Potter" -Category "xvid" -HasNfo
        Returns: harry/potter/category:xvid/nfo:yes

    .EXAMPLE
        ConvertTo-SatSearchQuery -ReleaseName "Some.Release.Name-GROUP"
        Returns: r:Some.Release.Name-GROUP

    .OUTPUTS
        String
        Returns the search path segment for the srrDB API
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]
        $Query,

        [Parameter(Mandatory = $false)]
        [string]
        $ReleaseName,

        [Parameter(Mandatory = $false)]
        [string]
        $Group,

        [Parameter(Mandatory = $false)]
        [ValidateSet('tv', 'xvid', 'x264', 'dvdr', 'xxx', 'pc', 'mac', 'linux', 'psx', 'ps2', 'ps3', 'ps4', 'ps5',
                     'psp', 'psv', 'xbox', 'xbox360', 'xboxone', 'gc', 'wii', 'wiiu', 'switch', 'nds', '3ds',
                     'music', 'mvid', 'mdvdr', 'ebook', 'audiobook', 'flac', 'mp3', 'games', 'apps', 'dox')]
        [string]
        $Category,

        [Parameter(Mandatory = $false)]
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
        [ValidateRange(1, 500)]
        [int]
        $MaxResults
    )

    $searchParts = @()

    # If exact release name is specified, use r: prefix (faster API lookup)
    if ($ReleaseName) {
        $searchParts += "r:$ReleaseName"
    }

    # Add query terms (split by spaces and join with slashes)
    # URL-encode each term to prevent injection attacks
    if ($Query) {
        $queryTerms = $Query -split '\s+' | Where-Object { $_ }
        foreach ($term in $queryTerms) {
            $encodedTerm = [System.Uri]::EscapeDataString($term.ToLower())
            $searchParts += $encodedTerm
        }
    }

    # Add category filter
    if ($Category) {
        $searchParts += "category:$($Category.ToLower())"
    }

    # Add group filter (URL-encode to prevent injection)
    if ($Group) {
        $encodedGroup = [System.Uri]::EscapeDataString($Group)
        $searchParts += "group:$encodedGroup"
    }

    # Add IMDB filter (normalize to just the ID number if tt prefix provided)
    if ($ImdbId) {
        $normalizedImdb = $ImdbId -replace '^tt', ''
        $searchParts += "imdb:tt$normalizedImdb"
    }

    # Add NFO filter
    if ($HasNfo) {
        $searchParts += 'nfo:yes'
    }

    # Add SRS filter
    if ($HasSrs) {
        $searchParts += 'srs:yes'
    }

    # Add date filter
    if ($Date) {
        $searchParts += "date:$Date"
    }

    # Join all parts with slashes
    $searchPath = $searchParts -join '/'

    return $searchPath
}
