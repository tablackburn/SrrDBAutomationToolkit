---
external help file: SrrDBAutomationToolkit-help.xml
Module Name: SrrDBAutomationToolkit
online version:
schema: 2.0.0
---

# Get-SatSrr

## SYNOPSIS
Downloads the SRR file for a release from srrDB.

## SYNTAX

```
Get-SatSrr [-ReleaseName] <String> [-OutPath] <String> [-PassThru] [-ProgressAction <ActionPreference>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Downloads the SRR (ReScene) file for a scene release.
SRR files contain
the metadata needed to reconstruct the original scene release structure.

## EXAMPLES

### EXAMPLE 1
```
Get-SatSrr -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS" -OutPath "C:\SRR"
```

Downloads the SRR file to C:\SRR\Inception.2010.1080p.BluRay.x264-SPARKS.srr

### EXAMPLE 2
```
Search-SatRelease -Query "Inception" | Get-SatSrr -OutPath "C:\SRR"
```

Searches for releases and downloads their SRR files.

### EXAMPLE 3
```
Get-SatSrr -ReleaseName "Some.Release-GROUP" -OutPath "." -PassThru
```

Downloads the SRR file to the current directory and returns the FileInfo object.

## PARAMETERS

### -ReleaseName
The release dirname to download.
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

### -OutPath
The directory where the SRR file should be saved.
The filename will be {ReleaseName}.srr

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
If specified, returns a FileInfo object for the downloaded file.

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
### If -PassThru is specified, returns System.IO.FileInfo for the downloaded file.
## NOTES

## RELATED LINKS
