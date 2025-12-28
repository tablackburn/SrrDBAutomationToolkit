# Taken with love from https://github.com/PowerShell/DscResource.Tests/blob/master/MetaFixers.psm1

<#
    This module helps fix problems, found by Meta.Tests.ps1
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

function ConvertTo-UTF8 {
    <#
    .SYNOPSIS
    Converts a file to UTF-8 encoding.

    .DESCRIPTION
    Reads the raw content of a file and writes it back to the file in UTF-8 encoding.

    .PARAMETER FileInfo
    Specifies the path to the file to convert.

    .EXAMPLE
    ConvertTo-UTF8 -FileInfo 'C:\path\to\file.txt'

    This example converts the file 'C:\path\to\file.txt' to UTF-8 encoding.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.IO.FileInfo]$FileInfo
    )

    process {
        $content = Get-Content -Path $FileInfo.FullName -Encoding 'Unicode' -Raw
        [System.IO.File]::WriteAllText($FileInfo.FullName, $content, [System.Text.Encoding]::UTF8)
    }
}

function ConvertTo-SpaceIndentation {
    <#
    .SYNOPSIS
    Converts tabs to spaces in a file.

    .DESCRIPTION
    Reads the raw content of a file and writes it back to the file with tabs replaced by spaces.

    .PARAMETER FileInfo
    Specifies the path to the file to convert.

    .EXAMPLE
    ConvertTo-SpaceIndentation -FileInfo 'C:\path\to\file.txt'

    This example converts the file 'C:\path\to\file.txt' to use spaces for indentation.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.IO.FileInfo]$FileInfo
    )

    process {
        $content = (Get-Content -Raw -Path $FileInfo.FullName) -replace "`t", '    '
        [System.IO.File]::WriteAllText($FileInfo.FullName, $content)
    }
}

function Get-TextFilesList {
    <#
    .SYNOPSIS
    Returns a list of text files.

    .DESCRIPTION
    Recursively searches for text files in a directory.

    .PARAMETER Root
    Specifies the root directory to search.

    .EXAMPLE
    Get-TextFilesList -Root 'C:\path\to\directory'

    This example returns a list of text files in the directory 'C:\path\to\directory'.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Root
    )

    begin {
        $textFileExtensions = @(
            '.cmd'
            '.gitattributes'
            '.gitignore'
            '.json'
            '.mof'
            '.ps1'
            '.psd1'
            '.psm1'
            '.xml'
        )
    }

    process {
        Get-ChildItem -Path $Root -File -Recurse | Where-Object {
            $_.Extension -in $textFileExtensions
        }
    }
}

function Test-FileUnicode {
    <#
    .SYNOPSIS
    Determines if a file is Unicode encoded.

    .DESCRIPTION
    Reads the raw bytes of a file and determines if it is Unicode encoded.

    .PARAMETER FileInfo
    Specifies the path to the file to test.

    .EXAMPLE
    Test-FileUnicode -FileInfo 'C:\path\to\file.txt'

    This example returns $true if the file 'C:\path\to\file.txt' is Unicode encoded.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.IO.FileInfo]$FileInfo
    )

    process {
        $bytes     = [System.IO.File]::ReadAllBytes($FileInfo.FullName)
        $zeroBytes = @($bytes -eq 0)
        return [bool]$zeroBytes.Length
    }
}

function Get-UnicodeFilesList {
    <#
    .SYNOPSIS
    Returns a list of Unicode encoded files.

    .DESCRIPTION
    Recursively searches for Unicode encoded files in a directory.

    .PARAMETER Root
    Specifies the root directory to search.

    .EXAMPLE
    Get-UnicodeFilesList -Root 'C:\path\to\directory'

    This example returns a list of Unicode encoded files in the directory 'C:\path\to\directory'.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $root | Get-TextFilesList | Where-Object {
        Test-FileUnicode $_
    }
}
