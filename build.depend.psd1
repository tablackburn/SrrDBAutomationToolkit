# Build dependencies for SrrDBAutomationToolkit
# These are the modules needed for building and testing the module
@{
    PSDependOptions    = @{
        Target     = 'CurrentUser'
        Parameters = @{
            Repository = 'PSGallery'
        }
    }
    'Pester'           = @{
        Version    = '5.7.1'
        Parameters = @{
            SkipPublisherCheck = $true
        }
    }
    'psake'            = @{
        Version = '4.9.1'
    }
    'BuildHelpers'     = @{
        Version = '2.0.16'
    }
    'PowerShellBuild'  = @{
        Version = '0.7.3'
    }
    'PSScriptAnalyzer' = @{
        Version = '1.24.0'
    }
}
