function Join-SatUri {
    <#
    .SYNOPSIS
        Joins a base URI with an endpoint path.

    .DESCRIPTION
        Safely combines a base URI with an endpoint path using the .NET Uri class.
        Handles trailing and leading slashes automatically.

    .PARAMETER BaseUri
        The base URI (default: https://api.srrdb.com/v1)

    .PARAMETER Endpoint
        The endpoint path to append (e.g., /details/ReleaseName)

    .PARAMETER QueryString
        Optional query string to append to the URI (without leading ?).
        IMPORTANT: Query string values must be URL-encoded before passing to this function.
        Use [System.Uri]::EscapeDataString() to encode parameter values.

    .EXAMPLE
        Join-SatUri -Endpoint "/details/Some.Release.Name"
        Returns: https://api.srrdb.com/v1/details/Some.Release.Name

    .EXAMPLE
        Join-SatUri -Endpoint "/search/harry/potter"
        Returns: https://api.srrdb.com/v1/search/harry/potter
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $BaseUri = 'https://api.srrdb.com/v1',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Endpoint,

        [Parameter(Mandatory = $false)]
        [ValidateScript({
            # Validate that QueryString doesn't contain unencoded special characters that could indicate injection
            if ($_ -match '[<>\"''\x00-\x1F]') {
                throw "QueryString contains invalid characters. Ensure values are properly URL-encoded using [System.Uri]::EscapeDataString()"
            }
            $true
        })]
        [string]
        $QueryString
    )

    try {
        # Validate that BaseUri is a valid URI
        $null = [Uri]::new($BaseUri)

        # Ensure base URI ends with / for proper path joining
        $normalizedBase = $BaseUri.TrimEnd('/')
        # Ensure endpoint starts with / for consistency
        $normalizedEndpoint = if ($Endpoint.StartsWith('/')) { $Endpoint } else { "/$Endpoint" }
        $uri = "$normalizedBase$normalizedEndpoint"

        if ($QueryString) {
            $uri += "?$QueryString"
        }

        return $uri
    }
    catch {
        $errorRecord = $_
        throw "Failed to join URI: $($errorRecord.Exception.Message)"
    }
}
