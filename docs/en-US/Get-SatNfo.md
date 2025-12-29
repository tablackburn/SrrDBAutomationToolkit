---
external help file: SrrDBAutomationToolkit-help.xml
Module Name: SrrDBAutomationToolkit
online version:
schema: 2.0.0
---

# Get-SatNfo

## SYNOPSIS
Gets NFO file information for a release from srrDB.

## SYNTAX

### Info (Default)
```
Get-SatNfo -ReleaseName <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Download
```
Get-SatNfo -ReleaseName <String> [-Download] [-OutPath <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### AsString
```
Get-SatNfo -ReleaseName <String> [-AsString] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves NFO file details for a scene release, including the NFO filename
and download URL.
Can optionally download the NFO content or save it to a file.

## EXAMPLES

### EXAMPLE 1
```
Get-SatNfo -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS"
```

Gets NFO file information including the download URL.

### EXAMPLE 2
```
Get-SatNfo -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS" -Download
```

Downloads and displays the NFO content.

### EXAMPLE 3
```
Get-SatNfo -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS" -OutPath "C:\NFOs"
```

Downloads the NFO file and saves it to C:\NFOs\sparks.nfo (or similar).

### EXAMPLE 4
```
Search-SatRelease -Query "Inception" -HasNfo | Get-SatNfo -Download
```

Searches for releases with NFOs and downloads their content.

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
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Download
If specified, downloads and returns the NFO content as a string.

```yaml
Type: SwitchParameter
Parameter Sets: Download
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutPath
If specified, downloads the NFO and saves it to the specified directory.
The filename will be the original NFO filename from the release.

```yaml
Type: String
Parameter Sets: Download
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsString
If specified, downloads and returns the NFO content as a string instead
of saving to a file.

```yaml
Type: SwitchParameter
Parameter Sets: AsString
Aliases:

Required: True
Position: Named
Default value: False
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

### PSCustomObject with properties:
### - Release: Release dirname
### - NfoFile: NFO filename
### - DownloadUrl: URL to download the NFO file
### If -Download is specified, returns the NFO content as a string.
### If -OutPath is specified, returns a FileInfo object for the saved file.
## NOTES

## RELATED LINKS
