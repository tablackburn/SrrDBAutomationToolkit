---
external help file: SrrDBAutomationToolkit-help.xml
Module Name: SrrDBAutomationToolkit
online version:
schema: 2.0.0
---

# Get-SatReleaseFile

## SYNOPSIS
Downloads all available files for a release from srrDB.

## SYNTAX

```
Get-SatReleaseFile [-ReleaseName] <String> [-OutPath <String>] [-PassThru] [-SkipAdditionalFiles]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Searches for a release on srrDB, downloads the SRR file, and downloads any
additional files (proofs, NFOs, etc.) stored on srrDB.
This is a high-level
function that orchestrates Search-SatRelease, Get-SatSrr, Get-SatRelease,
and Get-SatFile.

The search performs an exact match first, then falls back to fuzzy search
if no exact match is found.

## EXAMPLES

### EXAMPLE 1
```
Get-SatReleaseFile -ReleaseName "Movie.2024.1080p.BluRay.x264-GROUP" -OutPath "D:\Downloads"
```

Searches for the release, downloads the SRR and any additional files to D:\Downloads.

### EXAMPLE 2
```
Get-SatReleaseFile -ReleaseName "Movie.2024.1080p.BluRay.x264-GROUP" -SkipAdditionalFiles
```

Downloads only the SRR file to the current directory.

### EXAMPLE 3
```
Get-SatReleaseFile -ReleaseName "Movie.2024.1080p.BluRay.x264-GROUP" -PassThru
```

Downloads files and returns information about what was downloaded.

## PARAMETERS

### -ReleaseName
The release dirname to search for and download files from.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Release, Name

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -OutPath
The directory where files should be saved.
Defaults to the current directory.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
If specified, returns information about the downloaded files.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipAdditionalFiles
If specified, only downloads the SRR file and skips additional files
(proofs, NFOs, etc.).

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### None by default.
### If -PassThru is specified, returns a PSCustomObject with:
### - ReleaseName: The matched release name from srrDB
### - SrrFile: FileInfo for the downloaded SRR
### - AdditionalFiles: Array of FileInfo for additional downloaded files
## NOTES

## RELATED LINKS
