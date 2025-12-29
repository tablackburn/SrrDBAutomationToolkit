function Get-SatSrr {
    <#
    .SYNOPSIS
        Downloads the SRR file for a release from srrDB.

    .DESCRIPTION
        Downloads the SRR (ReScene) file for a scene release. SRR files contain
        the metadata needed to reconstruct the original scene release structure.

    .PARAMETER ReleaseName
        The release dirname to download. This is the exact scene release name.
        Supports pipeline input.

    .PARAMETER OutPath
        The directory where the SRR file should be saved. Defaults to the current
        directory if not specified. The filename will be {ReleaseName}.srr

    .PARAMETER PassThru
        If specified, returns a FileInfo object for the downloaded file.

    .EXAMPLE
        Get-SatSrr -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS"

        Downloads the SRR file to the current directory.

    .EXAMPLE
        Get-SatSrr -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS" -OutPath "C:\SRR"

        Downloads the SRR file to C:\SRR\Inception.2010.1080p.BluRay.x264-SPARKS.srr

    .EXAMPLE
        Search-SatRelease -Query "Inception" | Get-SatSrr

        Searches for releases and downloads their SRR files to the current directory.

    .EXAMPLE
        Get-SatSrr -ReleaseName "Some.Release-GROUP" -PassThru

        Downloads the SRR file to the current directory and returns the FileInfo object.

    .OUTPUTS
        None by default.
        If -PassThru is specified, returns System.IO.FileInfo for the downloaded file.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Release')]
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
        $PassThru
    )

    process {
        try {
            $encodedRelease = [System.Uri]::EscapeDataString($ReleaseName)
            $downloadUrl = "https://www.srrdb.com/download/srr/$encodedRelease"
            # Sanitize filename to remove all invalid filesystem characters
            $safeReleaseName = $ReleaseName
            $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
            foreach ($char in $invalidChars) {
                $safeReleaseName = $safeReleaseName.Replace($char, '_')
            }
            $fileName = "$safeReleaseName.srr"

            # Use OutPath if specified, otherwise current directory
            $targetPath = if ($OutPath) { $OutPath } else { Get-Location -PSProvider FileSystem | Select-Object -ExpandProperty Path }
            $filePath = Join-Path -Path $targetPath -ChildPath $fileName

            Write-Verbose "Downloading SRR file: $downloadUrl"

            if ($PSCmdlet.ShouldProcess($ReleaseName, "Download SRR file to $filePath")) {
                $webRequestParameters = @{
                    Uri         = $downloadUrl
                    OutFile     = $filePath
                    ErrorAction = 'Stop'
                }

                Invoke-WebRequest @webRequestParameters

                Write-Verbose "SRR file saved to: $filePath"

                if ($PassThru) {
                    return Get-Item -Path $filePath
                }
            }
        }
        catch {
            $errorRecord = $_
            throw "Failed to download SRR for '$ReleaseName': $($errorRecord.Exception.Message)"
        }
    }
}
