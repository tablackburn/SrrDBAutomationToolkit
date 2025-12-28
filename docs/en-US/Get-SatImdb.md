---
external help file: SrrDBAutomationToolkit-help.xml
Module Name: SrrDBAutomationToolkit
online version:
schema: 2.0.0
---

# Get-SatImdb

## SYNOPSIS
Gets IMDB information linked to a release from srrDB.

## SYNTAX

```
Get-SatImdb [-ReleaseName] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves IMDB metadata associated with a scene release, including
title, year, rating, and other movie/show information.

## EXAMPLES

### EXAMPLE 1
```
Get-SatImdb -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS"
```

Gets IMDB information linked to the specified release.

### EXAMPLE 2
```
Search-SatRelease -Query "Inception" | Get-SatImdb
```

Searches for releases and gets their IMDB information.

### EXAMPLE 3
```
"Inception.2010.1080p.BluRay.x264-SPARKS" | Get-SatImdb
```

Gets IMDB info using pipeline input.

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

### PSCustomObject with properties:
### - Release: Release dirname
### - ImdbId: IMDB ID (e.g., tt1375666)
### - Title: Movie/show title
### - Year: Release year
### - Rating: IMDB rating
### - Votes: Number of votes
### - Genre: Genre(s)
### - Director: Director name(s)
### - Actors: Actor names
## NOTES

## RELATED LINKS
