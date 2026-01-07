function Get-SatFile {
    <#
    .SYNOPSIS
        Downloads a stored file from srrDB for a release.

    .DESCRIPTION
        Downloads any stored file (proof images, NFO, SFV, etc.) from the srrDB database
        for a specific release. This is used to download files that are stored on srrDB
        but not embedded within the SRR file itself.

    .PARAMETER ReleaseName
        The release dirname. This is the exact scene release name.
        Supports pipeline input.

    .PARAMETER FileName
        The name of the file to download (e.g., "proof.jpg", "release.nfo").
        Can include path components (e.g., "Proof/proof.jpg").

    .PARAMETER OutPath
        The directory where the file should be saved. Defaults to the current
        directory if not specified.
        The file will be saved with its original filename (path components stripped).

    .PARAMETER PassThru
        If specified, returns a FileInfo object for the downloaded file.

    .EXAMPLE
        Get-SatFile -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS" -FileName "proof.jpg" -OutPath "C:\Downloads"

        Downloads the proof image to C:\Downloads\proof.jpg

    .EXAMPLE
        Get-SatFile -ReleaseName "Movie.2024-GROUP" -FileName "Proof/proof-movie.jpg" -OutPath "."

        Downloads the proof image from the Proof subdirectory.

    .EXAMPLE
        Get-SatRelease "Some.Release-GROUP" | ForEach-Object { $_.Files } | Get-SatFile -OutPath "."

        Gets release details and downloads all stored files.

    .EXAMPLE
        Get-SatFile -ReleaseName "Some.Release-GROUP" -FileName "proof.jpg" -OutPath "." -PassThru

        Downloads the file and returns the FileInfo object.

    .OUTPUTS
        None by default.
        If -PassThru is specified, returns System.IO.FileInfo for the downloaded file.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Release', 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ReleaseName,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('File')]
        [ValidateNotNullOrEmpty()]
        [string]
        $FileName,

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
        $PassThru
    )

    process {
        try {
            $encodedRelease = [System.Uri]::EscapeDataString($ReleaseName)
            # Encode each path segment separately to preserve forward slashes
            # srrdb expects paths like: /download/file/Release/Proof/file.jpg (not Proof%2Ffile.jpg)
            $encodedFileName = ($FileName -split '/') | ForEach-Object {
                [System.Uri]::EscapeDataString($_)
            } | Join-String -Separator '/'
            $downloadUrl = "https://www.srrdb.com/download/file/$encodedRelease/$encodedFileName"

            # Extract just the filename (last path component) for local storage
            $localFileName = Split-Path -Path $FileName -Leaf
            # Sanitize filename to remove invalid filesystem characters using platform-specific rules
            $safeFileName = $localFileName
            $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
            foreach ($char in $invalidChars) {
                $safeFileName = $safeFileName.Replace($char, '_')
            }
            
            # Use OutPath if specified, otherwise current directory
            $targetPath = if ($OutPath) { $OutPath } else { Get-Location -PSProvider FileSystem | Select-Object -ExpandProperty Path }
            $filePath = Join-Path -Path $targetPath -ChildPath $safeFileName

            Write-Verbose "Downloading file: $downloadUrl"

            if ($PSCmdlet.ShouldProcess("$ReleaseName/$FileName", "Download file to $filePath")) {
                $webRequestParameters = @{
                    Uri         = $downloadUrl
                    OutFile     = $filePath
                    ErrorAction = 'Stop'
                }

                Invoke-WebRequest @webRequestParameters

                Write-Verbose "File saved to: $filePath"

                if ($PassThru) {
                    return Get-Item -Path $filePath
                }
            }
        }
        catch {
            $errorRecord = $_
            throw "Failed to download '$FileName' for '$ReleaseName': $($errorRecord.Exception.Message)"
        }
    }
}
