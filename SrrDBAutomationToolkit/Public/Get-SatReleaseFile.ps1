function Get-SatReleaseFile {
    <#
    .SYNOPSIS
        Downloads all available files for a release from srrDB.

    .DESCRIPTION
        Searches for a release on srrDB, downloads the SRR file, and downloads any
        additional files (proofs, NFOs, etc.) stored on srrDB. This is a high-level
        function that orchestrates Search-SatRelease, Get-SatSrr, Get-SatRelease,
        and Get-SatFile.

        The search performs an exact match first, then falls back to fuzzy search
        if no exact match is found.

    .PARAMETER ReleaseName
        The release dirname to search for and download files from.

    .PARAMETER OutPath
        The directory where files should be saved. Defaults to the current directory.

    .PARAMETER PassThru
        If specified, returns information about the downloaded files.

    .PARAMETER SkipAdditionalFiles
        If specified, only downloads the SRR file and skips additional files
        (proofs, NFOs, etc.).

    .EXAMPLE
        Get-SatReleaseFile -ReleaseName "Movie.2024.1080p.BluRay.x264-GROUP" -OutPath "D:\Downloads"

        Searches for the release, downloads the SRR and any additional files to D:\Downloads.

    .EXAMPLE
        Get-SatReleaseFile -ReleaseName "Movie.2024.1080p.BluRay.x264-GROUP" -SkipAdditionalFiles

        Downloads only the SRR file to the current directory.

    .EXAMPLE
        Get-SatReleaseFile -ReleaseName "Movie.2024.1080p.BluRay.x264-GROUP" -PassThru

        Downloads files and returns information about what was downloaded.

    .OUTPUTS
        None by default.
        If -PassThru is specified, returns a PSCustomObject with:
        - ReleaseName: The matched release name from srrDB
        - SrrFile: FileInfo for the downloaded SRR
        - AdditionalFiles: Array of FileInfo for additional downloaded files
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Release', 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ReleaseName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Test-Path -Path $_ -PathType Container)) {
                throw "Directory does not exist: $_"
            }
            $true
        })]
        [string]
        $OutPath,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru,

        [Parameter(Mandatory = $false)]
        [switch]
        $SkipAdditionalFiles
    )

    process {
        try {
            # Resolve output path
            $targetPath = if ($OutPath) { $OutPath } else { Get-Location -PSProvider FileSystem | Select-Object -ExpandProperty Path }

            # Step 1: Search for the release (exact match first)
            Write-Verbose "Searching for release: $ReleaseName"
            $searchResult = Search-SatRelease -ReleaseName $ReleaseName -ErrorAction SilentlyContinue

            if (-not $searchResult) {
                # Try fuzzy search
                Write-Verbose "Exact match not found, trying fuzzy search..."
                $searchResult = Search-SatRelease -Query $ReleaseName -MaxResults 5 -ErrorAction SilentlyContinue
            }

            if (-not $searchResult) {
                throw "Release not found on srrDB: $ReleaseName"
            }

            # Find exact match or use first fuzzy result
            $matchedRelease = if ($searchResult -is [array]) {
                $exactMatch = $searchResult | Where-Object { $_.Release -eq $ReleaseName } | Select-Object -First 1
                if ($exactMatch) {
                    $exactMatch
                }
                else {
                    $searchResult[0]
                }
            }
            else {
                $searchResult
            }

            $actualReleaseName = $matchedRelease.Release
            Write-Verbose "Matched release: $actualReleaseName"

            # Step 2: Download SRR file
            Write-Verbose "Downloading SRR file..."
            $srrFile = $null
            if ($PSCmdlet.ShouldProcess($actualReleaseName, "Download SRR file")) {
                $srrFile = Get-SatSrr -ReleaseName $actualReleaseName -OutPath $targetPath -PassThru -ErrorAction Stop
                Write-Verbose "Downloaded: $($srrFile.Name)"
            }

            # Step 3: Download additional files (if not skipped)
            $additionalFiles = @()
            if (-not $SkipAdditionalFiles) {
                Write-Verbose "Getting release details for additional files..."
                $releaseDetails = Get-SatRelease -ReleaseName $actualReleaseName -ErrorAction Stop

                if ($releaseDetails.Files -and $releaseDetails.Files.Count -gt 0) {
                    Write-Verbose "Found $($releaseDetails.Files.Count) files on srrDB"

                    foreach ($file in $releaseDetails.Files) {
                        $fileName = $file.name
                        if (-not $fileName) { continue }

                        # Skip SRR and SRS files (SRS should be embedded in SRR)
                        if ($fileName -match '\.(srr|srs)$') {
                            Write-Verbose "Skipping $fileName (SRR/SRS file)"
                            continue
                        }

                        # Check if file already exists
                        $localFileName = Split-Path -Path $fileName -Leaf
                        $localFilePath = Join-Path -Path $targetPath -ChildPath $localFileName

                        if (Test-Path -Path $localFilePath) {
                            Write-Verbose "Skipping $fileName (already exists)"
                            continue
                        }

                        # Download the file
                        if ($PSCmdlet.ShouldProcess("$actualReleaseName/$fileName", "Download additional file")) {
                            try {
                                $downloadedFile = Get-SatFile -ReleaseName $actualReleaseName -FileName $fileName -OutPath $targetPath -PassThru -ErrorAction Stop
                                $additionalFiles += $downloadedFile
                                Write-Verbose "Downloaded: $localFileName"
                            }
                            catch {
                                Write-Warning "Failed to download ${fileName}: $($_.Exception.Message)"
                            }
                        }
                    }
                }
            }

            # Return results if PassThru
            if ($PassThru) {
                [PSCustomObject]@{
                    PSTypeName      = 'SrrDBAutomationToolkit.ReleaseFiles'
                    ReleaseName     = $actualReleaseName
                    SrrFile         = $srrFile
                    AdditionalFiles = $additionalFiles
                }
            }
        }
        catch {
            $errorRecord = $_
            throw "Failed to get release files for '$ReleaseName': $($errorRecord.Exception.Message)"
        }
    }
}
