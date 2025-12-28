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

    .PARAMETER Skip
        Number of results to skip for pagination.

    .PARAMETER Foreign
        If specified, filter to foreign (non-English) releases.

    .PARAMETER Confirmed
        If specified, filter to confirmed releases only.

    .PARAMETER RarHash
        Filter by RAR file hash.

    .PARAMETER ArchiveCrc
        Filter by archive CRC value.

    .PARAMETER ArchiveSize
        Filter by archive size in bytes.

    .PARAMETER InternetSubtitlesDbHash
        Filter by Internet Subtitles Database (ISDb) hash.

    .PARAMETER Compressed
        If specified, filter to compressed releases.

    .PARAMETER Order
        Sort order for results. Valid values: date-asc, date-desc, release-asc, release-desc.

    .PARAMETER Country
        Filter by country code (e.g., US, UK, DE).

    .PARAMETER Language
        Filter by language (e.g., English, German, French).

    .PARAMETER SampleFilename
        Filter by sample filename stored inside SRS (Sample Rescue Service) files.

    .PARAMETER SampleCrc
        Filter by CRC32 of the sample video stored inside SRS files.

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
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $Skip,

        [Parameter(Mandatory = $false)]
        [switch]
        $Foreign,

        [Parameter(Mandatory = $false)]
        [switch]
        $Confirmed,

        [Parameter(Mandatory = $false)]
        [string]
        $RarHash,

        [Parameter(Mandatory = $false)]
        [string]
        $ArchiveCrc,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, [long]::MaxValue)]
        [long]
        $ArchiveSize,

        [Parameter(Mandatory = $false)]
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
        [string]
        $Country,

        [Parameter(Mandatory = $false)]
        [string]
        $Language,

        [Parameter(Mandatory = $false)]
        [string]
        $SampleFilename,

        [Parameter(Mandatory = $false)]
        [string]
        $SampleCrc
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

    # Add skip filter for pagination
    if ($PSBoundParameters.ContainsKey('Skip') -and $Skip -gt 0) {
        $searchParts += "skip:$Skip"
    }

    # Add foreign filter
    if ($Foreign) {
        $searchParts += 'foreign:yes'
    }

    # Add confirmed filter
    if ($Confirmed) {
        $searchParts += 'confirmed:yes'
    }

    # Add rarhash filter (URL-encode to prevent injection)
    if ($RarHash) {
        $encodedRarHash = [System.Uri]::EscapeDataString($RarHash)
        $searchParts += "rarhash:$encodedRarHash"
    }

    # Add archive-crc filter (URL-encode to prevent injection)
    if ($ArchiveCrc) {
        $encodedArchiveCrc = [System.Uri]::EscapeDataString($ArchiveCrc)
        $searchParts += "archive-crc:$encodedArchiveCrc"
    }

    # Add archive-size filter
    if ($PSBoundParameters.ContainsKey('ArchiveSize')) {
        $searchParts += "archive-size:$ArchiveSize"
    }

    # Add isdbhash filter (URL-encode to prevent injection)
    if ($InternetSubtitlesDbHash) {
        $encodedIsdbHash = [System.Uri]::EscapeDataString($InternetSubtitlesDbHash)
        $searchParts += "isdbhash:$encodedIsdbHash"
    }

    # Add compressed filter
    if ($Compressed) {
        $searchParts += 'compressed:yes'
    }

    # Add order filter
    if ($Order) {
        $searchParts += "order:$Order"
    }

    # Add country filter (URL-encode to prevent injection)
    if ($Country) {
        $encodedCountry = [System.Uri]::EscapeDataString($Country)
        $searchParts += "country:$encodedCountry"
    }

    # Add language filter (URL-encode to prevent injection)
    if ($Language) {
        $encodedLanguage = [System.Uri]::EscapeDataString($Language)
        $searchParts += "language:$encodedLanguage"
    }

    # Add store-real-filename filter (URL-encode to prevent injection)
    if ($SampleFilename) {
        $encodedFilename = [System.Uri]::EscapeDataString($SampleFilename)
        $searchParts += "store-real-filename:$encodedFilename"
    }

    # Add store-real-crc filter (URL-encode to prevent injection)
    if ($SampleCrc) {
        $encodedCrc = [System.Uri]::EscapeDataString($SampleCrc)
        $searchParts += "store-real-crc:$encodedCrc"
    }

    # Join all parts with slashes
    $searchPath = $searchParts -join '/'

    return $searchPath
}
