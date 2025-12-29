function Get-SatNfo {
    <#
    .SYNOPSIS
        Gets NFO file information for a release from srrDB.

    .DESCRIPTION
        Retrieves NFO file details for a scene release, including the NFO filename
        and download URL. Can optionally download the NFO to a file or return the
        content as a string.

    .PARAMETER ReleaseName
        The release dirname to look up. This is the exact scene release name.
        Supports pipeline input.

    .PARAMETER Download
        If specified, downloads the NFO and saves it to a file. By default, saves
        to the current directory. Use -OutPath to specify a different directory.

    .PARAMETER OutPath
        The directory to save downloaded NFO files to. Defaults to the current
        directory. Only used with -Download.

    .PARAMETER AsString
        If specified, downloads and returns the NFO content as a string instead
        of saving to a file.

    .EXAMPLE
        Get-SatNfo -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS"

        Gets NFO file information including the download URL.

    .EXAMPLE
        Get-SatNfo -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS" -Download

        Downloads the NFO file and saves it to the current directory.

    .EXAMPLE
        Get-SatNfo -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS" -Download -OutPath "C:\NFOs"

        Downloads the NFO file and saves it to C:\NFOs.

    .EXAMPLE
        Get-SatNfo -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS" -AsString

        Downloads and returns the NFO content as a string.

    .EXAMPLE
        Search-SatRelease -Query "Inception" -HasNfo | Get-SatNfo -Download

        Searches for releases with NFOs and downloads them to the current directory.

    .OUTPUTS
        PSCustomObject with properties:
        - Release: Release dirname
        - NfoFile: NFO filename
        - DownloadUrl: URL to download the NFO file

        If -Download is specified, returns a FileInfo object for the saved file.
        If -AsString is specified, returns the NFO content as a string.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Info')]
    [OutputType([PSCustomObject], ParameterSetName = 'Info')]
    [OutputType([System.IO.FileInfo], ParameterSetName = 'Download')]
    [OutputType([string], ParameterSetName = 'AsString')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Release')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ReleaseName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Download')]
        [switch]
        $Download,

        [Parameter(Mandatory = $false, ParameterSetName = 'Download')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Test-Path -Path $_ -PathType Container)) {
                throw "Directory does not exist: $_"
            }
            $true
        })]
        [string]
        $OutPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'AsString')]
        [switch]
        $AsString
    )

    process {
        try {
            $encodedRelease = [System.Uri]::EscapeDataString($ReleaseName)
            $endpoint = "/nfo/$encodedRelease"
            $uri = Join-SatUri -Endpoint $endpoint

            Write-Verbose "Getting NFO info: $uri"

            $result = Invoke-SatApi -Uri $uri -ErrorAction 'Stop'

            # Check for API errors
            if ($result.error) {
                throw "srrDB API error: $($result.error)"
            }

            # Check if NFO was found
            if (-not $result.nfolink -and -not $result.nfo) {
                Write-Warning "No NFO found for release: $ReleaseName"
                return
            }

            # Get NFO details (API returns arrays, take first element)
            $nfoFile = if ($result.nfo -is [array]) { $result.nfo[0] } else { $result.nfo }
            $nfoLink = if ($result.nfolink -is [array]) { $result.nfolink[0] } else { $result.nfolink }

            if (-not $nfoLink -and $nfoFile) {
                # Construct download URL if not provided
                $nfoLink = "https://www.srrdb.com/download/file/$encodedRelease/$([System.Uri]::EscapeDataString($nfoFile))"
            }

            # Handle download scenarios
            if ($Download -or $AsString) {
                Write-Verbose "Downloading NFO from: $nfoLink"

                $nfoContent = Invoke-RestMethod -Uri $nfoLink -ErrorAction 'Stop'

                if ($Download) {
                    # Save to file - sanitize filename to prevent path traversal
                    $rawFileName = if ($nfoFile) { $nfoFile } else { "$ReleaseName.nfo" }
                    # Remove any path components and invalid characters
                    $fileName = [System.IO.Path]::GetFileName($rawFileName)
                    $fileName = $fileName -replace '[\\/:*?"<>|]', '_'
                    # Ensure it ends with .nfo extension
                    if (-not $fileName.EndsWith('.nfo', [StringComparison]::OrdinalIgnoreCase)) {
                        $fileName = "$fileName.nfo"
                    }

                    # Use OutPath if specified, otherwise current directory
                    $targetPath = if ($OutPath) { $OutPath } else { Get-Location -PSProvider FileSystem | Select-Object -ExpandProperty Path }
                    $filePath = Join-Path -Path $targetPath -ChildPath $fileName

                    [System.IO.File]::WriteAllText($filePath, $nfoContent)

                    Write-Verbose "NFO saved to: $filePath"
                    return Get-Item -Path $filePath
                }
                else {
                    # Return content as string
                    return $nfoContent
                }
            }

            # Return info object
            [PSCustomObject]@{
                PSTypeName  = 'SrrDBAutomationToolkit.NfoInfo'
                Release     = $ReleaseName
                NfoFile     = $nfoFile
                DownloadUrl = $nfoLink
            }
        }
        catch {
            $errorRecord = $_
            throw "Failed to get NFO for '$ReleaseName': $($errorRecord.Exception.Message)"
        }
    }
}
