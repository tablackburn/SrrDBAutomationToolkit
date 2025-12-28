function Invoke-SatApi {
    <#
    .SYNOPSIS
        Invokes the srrDB API.

    .DESCRIPTION
        Internal function that sends HTTP requests to the srrDB API and returns the response.
        Handles JSON parsing, error handling, and automatic retries with exponential backoff
        for transient failures.

    .PARAMETER Uri
        The complete URI to call

    .PARAMETER Method
        The HTTP method to use (default: Get)

    .PARAMETER Headers
        Optional headers to include in the request (default: Accept = application/json)

    .PARAMETER MaxRetries
        Maximum number of retry attempts for transient failures (default: 3)

    .PARAMETER RetryDelaySeconds
        Initial delay in seconds before first retry. Doubles with each subsequent retry (default: 1.0)

    .PARAMETER RetryableStatusCodes
        HTTP status codes that should trigger a retry (default: 429, 500, 502, 503, 504)

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
        },

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 10)]
        [int]
        $MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0.1, 60)]
        [double]
        $RetryDelaySeconds = 1.0,

        [Parameter(Mandatory = $false)]
        [int[]]
        $RetryableStatusCodes = @(429, 500, 502, 503, 504)
    )

    $apiQueryParameters = @{
        Method      = $Method
        Uri         = $Uri
        Headers     = $Headers
        ErrorAction = 'Stop'
    }
    Write-Debug 'Invoking srrDB API with the following parameters:'
    $apiQueryParameters | Out-String | Write-Debug

    $attempt = 0
    $currentDelay = $RetryDelaySeconds
    $lastException = $null

    while ($attempt -le $MaxRetries) {
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
            $lastException = $_
            $shouldRetry = $false
            $statusCode = $null

            # Extract HTTP status code from exception
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
                $shouldRetry = $statusCode -in $RetryableStatusCodes
            }
            elseif ($_.Exception -is [System.Net.WebException]) {
                $webResponse = $_.Exception.Response -as [System.Net.HttpWebResponse]
                if ($webResponse) {
                    $statusCode = [int]$webResponse.StatusCode
                    $shouldRetry = $statusCode -in $RetryableStatusCodes
                }
                else {
                    # Connection error (no response) - retry
                    $shouldRetry = $true
                }
            }
            elseif ($_.Exception.Message -match 'timeout|timed out') {
                # Timeout - retry
                $shouldRetry = $true
            }

            if ($shouldRetry -and $attempt -lt $MaxRetries) {
                $attempt++
                $statusInfo = if ($statusCode) { " (HTTP $statusCode)" } else { "" }
                Write-Verbose "Request failed$statusInfo. Retrying in $currentDelay seconds... (Attempt $attempt of $MaxRetries)"
                Start-Sleep -Seconds $currentDelay
                $currentDelay = $currentDelay * 2  # Exponential backoff
            }
            else {
                # Non-retryable error or max retries exceeded
                if ($attempt -ge $MaxRetries -and $shouldRetry) {
                    throw "Error invoking srrDB API after $MaxRetries retries: $($lastException.Exception.Message)"
                }
                throw "Error invoking srrDB API: $($_.Exception.Message)"
            }
        }
    }
}
