---
external help file: SrrDBAutomationToolkit-help.xml
Module Name: SrrDBAutomationToolkit
online version:
schema: 2.0.0
---

# Get-SatFile

## SYNOPSIS
Downloads a stored file from srrDB for a release.

## SYNTAX

```
Get-SatFile [-ReleaseName] <String> [-FileName] <String> [[-OutPath] <String>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Downloads any stored file (proof images, NFO, SFV, etc.) from the srrDB database
for a specific release.
This is used to download files that are stored on srrDB
but not embedded within the SRR file itself.

## EXAMPLES

### EXAMPLE 1
```
Get-SatFile -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS" -FileName "proof.jpg" -OutPath "C:\Downloads"
```

Downloads the proof image to C:\Downloads\proof.jpg

### EXAMPLE 2
```
Get-SatFile -ReleaseName "Movie.2024-GROUP" -FileName "Proof/proof-movie.jpg" -OutPath "."
```

Downloads the proof image from the Proof subdirectory.

### EXAMPLE 3
```
Get-SatRelease "Some.Release-GROUP" | ForEach-Object { $_.Files } | Get-SatFile -OutPath "."
```

Gets release details and downloads all stored files.

### EXAMPLE 4
```
Get-SatFile -ReleaseName "Some.Release-GROUP" -FileName "proof.jpg" -OutPath "." -PassThru
```

Downloads the file and returns the FileInfo object.

## PARAMETERS

### -ReleaseName
The release dirname.
This is the exact scene release name.
Supports pipeline input.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Release, Name

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -FileName
The name of the file to download (e.g., "proof.jpg", "release.nfo").
Can include path components (e.g., "Proof/proof.jpg").

```yaml
Type: String
Parameter Sets: (All)
Aliases: File

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -OutPath
The directory where the file should be saved.
Defaults to the current
directory if not specified.
The file will be saved with its original filename (path components stripped).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
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
