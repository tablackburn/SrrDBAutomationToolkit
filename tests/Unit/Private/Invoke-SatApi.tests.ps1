BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'SrrDBAutomationToolkit'

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\Invoke-SatApi.ps1')
}

Describe 'Invoke-SatApi' {
    Context 'Parameter validation' {
        It 'Should throw on null Uri' {
            { Invoke-SatApi -Uri $null } | Should -Throw
        }

        It 'Should throw on empty Uri' {
            { Invoke-SatApi -Uri '' } | Should -Throw
        }
    }

    Context 'Default parameters' {
        BeforeAll {
            Mock Invoke-RestMethod { return @{ test = 'value' } }
        }

        It 'Should use GET method by default' {
            Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test'
            Should -Invoke Invoke-RestMethod -ParameterFilter { $Method -eq 'Get' }
        }

        It 'Should use Accept: application/json header by default' {
            Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test'
            Should -Invoke Invoke-RestMethod -ParameterFilter { $Headers.Accept -eq 'application/json' }
        }
    }

    Context 'Response handling' {
        It 'Should return parsed JSON response' {
            Mock Invoke-RestMethod { return @{ results = @('item1', 'item2') } }

            $result = Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test'
            $result.results | Should -HaveCount 2
        }

        It 'Should parse JSON string response' {
            Mock Invoke-RestMethod { return '{"test": "value"}' }

            $result = Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test'
            $result.test | Should -Be 'value'
        }
    }

    Context 'Error handling' {
        It 'Should throw with descriptive error message on failure' {
            # Create a non-retryable HTTP error (404)
            Mock Invoke-RestMethod {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
                $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Not Found", $response)
                throw $exception
            }

            { Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test' -MaxRetries 0 } |
                Should -Throw "*Error invoking srrDB API*"
        }
    }

    Context 'Retry logic' {
        It 'Should retry on HTTP 429 (rate limit)' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
                    $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Too Many Requests", $response)
                    throw $exception
                }
                return @{ success = $true }
            }
            Mock Start-Sleep { }

            $result = Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test' -RetryDelaySeconds 0.1
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }

        It 'Should retry on HTTP 500 (server error)' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::InternalServerError)
                    $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Internal Server Error", $response)
                    throw $exception
                }
                return @{ success = $true }
            }
            Mock Start-Sleep { }

            $result = Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test' -RetryDelaySeconds 0.1
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }

        It 'Should retry on HTTP 503 (service unavailable)' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::ServiceUnavailable)
                    $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Service Unavailable", $response)
                    throw $exception
                }
                return @{ success = $true }
            }
            Mock Start-Sleep { }

            $result = Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test' -RetryDelaySeconds 0.1
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }

        It 'Should NOT retry on HTTP 404 (not found)' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
                $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Not Found", $response)
                throw $exception
            }
            Mock Start-Sleep { }

            { Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test' -RetryDelaySeconds 0.1 } | Should -Throw
            $script:callCount | Should -Be 1
        }

        It 'Should NOT retry on HTTP 400 (bad request)' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::BadRequest)
                $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Bad Request", $response)
                throw $exception
            }
            Mock Start-Sleep { }

            { Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test' -RetryDelaySeconds 0.1 } | Should -Throw
            $script:callCount | Should -Be 1
        }

        It 'Should throw after max retries exceeded' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::ServiceUnavailable)
                $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Service Unavailable", $response)
                throw $exception
            }
            Mock Start-Sleep { }

            { Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test' -MaxRetries 2 -RetryDelaySeconds 0.1 } |
                Should -Throw "*after 2 retries*"
            $script:callCount | Should -Be 3  # Initial + 2 retries
        }

        It 'Should use exponential backoff' {
            $script:delays = @()
            Mock Invoke-RestMethod {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::ServiceUnavailable)
                $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Service Unavailable", $response)
                throw $exception
            }
            Mock Start-Sleep {
                param($Seconds)
                $script:delays += $Seconds
            }

            { Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test' -MaxRetries 3 -RetryDelaySeconds 1 } | Should -Throw

            $script:delays | Should -HaveCount 3
            $script:delays[0] | Should -Be 1
            $script:delays[1] | Should -Be 2
            $script:delays[2] | Should -Be 4
        }

        It 'Should retry on timeout exceptions' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw "The operation has timed out"
                }
                return @{ success = $true }
            }
            Mock Start-Sleep { }

            $result = Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test' -RetryDelaySeconds 0.1
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }

        It 'Should respect custom retryable status codes' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
                    $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Not Found", $response)
                    throw $exception
                }
                return @{ success = $true }
            }
            Mock Start-Sleep { }

            # 404 is not retryable by default, but we can make it retryable
            $result = Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test' -RetryableStatusCodes @(404) -RetryDelaySeconds 0.1
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }

        It 'Should succeed on first try without retrying' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                return @{ success = $true }
            }
            Mock Start-Sleep { }

            $result = Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test'
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 1
            Should -Invoke Start-Sleep -Times 0
        }

        It 'Should retry on connection errors (WebException without response)' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    $webException = [System.Net.WebException]::new("Unable to connect to remote server")
                    throw $webException
                }
                return @{ success = $true }
            }
            Mock Start-Sleep { }

            $result = Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test' -RetryDelaySeconds 0.1
            $result.success | Should -BeTrue
            $script:callCount | Should -Be 2
        }
    }

    Context 'Response parsing' {
        It 'Should parse JSON string response without -Depth on older PowerShell' {
            # This tests the ConvertFrom-Json fallback path
            Mock Invoke-RestMethod { return '{"nested": {"deep": "value"}}' }

            $result = Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test'
            $result.nested.deep | Should -Be 'value'
        }

    }

    # Note: Lines 113-116 in Invoke-SatApi.ps1 are legacy compatibility code
    # for .NET Framework WebException with HttpWebResponse handling.
    # In .NET Core/PS7, HTTP errors throw HttpResponseException, not WebException.
    # The WebException path with HttpWebResponse can only execute on Windows PowerShell 5.1.
}
