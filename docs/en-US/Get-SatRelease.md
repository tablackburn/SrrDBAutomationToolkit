---
external help file: SrrDBAutomationToolkit-help.xml
Module Name: SrrDBAutomationToolkit
online version:
schema: 2.0.0
---

# Get-SatRelease

## SYNOPSIS
Gets detailed information about a specific release from srrDB.

## SYNTAX

```
Get-SatRelease [-ReleaseName] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves comprehensive details about a scene release from the srrDB database,
including file information, archive details, and metadata.

## EXAMPLES

### EXAMPLE 1
```
Get-SatRelease -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS"
```

Gets detailed information about the specified release.

### EXAMPLE 2
```
Search-SatRelease -Query "Inception" | Get-SatRelease
```

Searches for releases and pipes them to get full details.

### EXAMPLE 3
```
"Inception.2010.1080p.BluRay.x264-SPARKS" | Get-SatRelease
```

Gets release details using pipeline input.

## PARAMETERS

### -ReleaseName
The release dirname to look up.
This is the exact scene release name.
Supports pipeline input.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Release

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
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

### PSCustomObject with release details including:
### - Name: Release dirname
### - Files: Array of files in the release
### - Archived: Array of archive files
### - ArchivedFiles: Files within archives
### - SrrSize: Size of the SRR file
### - HasNfo: Boolean indicating NFO availability
### - HasSrs: Boolean indicating SRS availability
## NOTES

## RELATED LINKS
