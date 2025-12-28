function Invoke-SatApi {
    <#
    .SYNOPSIS
        Invokes the srrDB API.

    .DESCRIPTION
        Internal function that sends HTTP requests to the srrDB API and returns the response.
        Handles JSON parsing and error handling for all API calls.

    .PARAMETER Uri
        The complete URI to call

    .PARAMETER Method
        The HTTP method to use (default: Get)

    .PARAMETER Headers
        Optional headers to include in the request (default: Accept = application/json)

    .OUTPUTS
        PSCustomObject
        Returns the parsed JSON response from the srrDB API
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Uri,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Method = 'Get',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Headers = @{
            Accept = 'application/json'
        }
    )

    $apiQueryParameters = @{
        Method      = $Method
        Uri         = $Uri
        Headers     = $Headers
        ErrorAction = 'Stop'
    }
    Write-Debug 'Invoking srrDB API with the following parameters:'
    $apiQueryParameters | Out-String | Write-Debug

    try {
        $response = Invoke-RestMethod @apiQueryParameters

        # Handle case where response is returned as JSON string (object or array)
        if ($response -is [string]) {
            $trimmed = $response.TrimStart()
            if ($trimmed.StartsWith('{') -or $trimmed.StartsWith('[')) {
                Write-Debug "Response is JSON string, parsing..."
                # Use -Depth only if available (PowerShell 6.0+)
                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    $response = $response | ConvertFrom-Json -Depth 100
                }
                else {
                    $response = $response | ConvertFrom-Json
                }
            }
        }

        return $response
    }
    catch {
        throw "Error invoking srrDB API: $($_.Exception.Message)"
    }
}
