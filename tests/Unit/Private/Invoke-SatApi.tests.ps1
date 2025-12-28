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
            Mock Invoke-RestMethod { throw "Connection failed" }

            { Invoke-SatApi -Uri 'https://api.srrdb.com/v1/test' } |
                Should -Throw "*Error invoking srrDB API*"
        }
    }
}
