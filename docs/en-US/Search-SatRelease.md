---
external help file: SrrDBAutomationToolkit-help.xml
Module Name: SrrDBAutomationToolkit
online version:
schema: 2.0.0
---

# Search-SatRelease

## SYNOPSIS
Searches for releases in the srrDB database.

## SYNTAX

### Query (Default)
```
Search-SatRelease [-Query] <String> [-Group <String>] [-Category <String>] [-ImdbId <String>] [-HasNfo]
 [-HasSrs] [-Date <String>] [-MaxResults <Int32>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ReleaseName
```
Search-SatRelease -ReleaseName <String> [-Group <String>] [-Category <String>] [-ImdbId <String>] [-HasNfo]
 [-HasSrs] [-Date <String>] [-MaxResults <Int32>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Searches the srrDB scene release database using various filters and criteria.
Returns matching releases with basic information including release name,
date, and availability of NFO/SRS files.

## EXAMPLES

### EXAMPLE 1
```
Search-SatRelease -Query "Harry Potter"
```

Searches for releases containing "Harry" and "Potter" in the name.

### EXAMPLE 2
```
Search-SatRelease -Query "Matrix" -Skip 100
```

Searches for "Matrix" releases, skipping the first 100 results (page 2+).

### EXAMPLE 3
```
Search-SatRelease -Query "Inception" -Category "x264" -HasNfo
```

Searches for x264 releases of "Inception" that have NFO files.

### EXAMPLE 4
```
Search-SatRelease -Group "SPARKS" -Category "xvid"
```

Finds all xvid releases from the SPARKS group.

### EXAMPLE 5
```
Search-SatRelease -ImdbId "tt1375666"
```

Searches for all releases linked to IMDB ID tt1375666 (Inception).

### EXAMPLE 6
```
Search-SatRelease -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS"
```

Performs a fast exact-match lookup for the specified release name.

## PARAMETERS

### -Query
Free-text search terms.
Searches across release names.

```yaml
Type: String
Parameter Sets: Query
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReleaseName
Exact release name to search for.
Uses the faster r: prefix internally
for direct lookups.

```yaml
Type: String
Parameter Sets: ReleaseName
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Group
Filter results to a specific release group.

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

### -Category
Filter by release category.
Valid values include:
tv, xvid, x264, dvdr, xxx, pc, mac, linux, psx, ps2, ps3, ps4, ps5,
psp, psv, xbox, xbox360, xboxone, gc, wii, wiiu, switch, nds, 3ds,
music, mvid, mdvdr, ebook, audiobook, flac, mp3, games, apps, dox

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

### -ImdbId
Filter by IMDB ID.
Can include or exclude the 'tt' prefix.

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

### -HasNfo
If specified, only return releases that have NFO files.

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

### -HasSrs
If specified, only return releases that have SRS (Sample Rescue Service) files.

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

### -Date
Filter by the date the release was added to the database.
Format: YYYY-MM-DD

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

### -MaxResults
Maximum number of results to return (1-500).
Default is all results from the
current page.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 0
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
### - Release: The release dirname
### - Date: Date added to database
### - HasNfo: Boolean indicating NFO availability
### - HasSrs: Boolean indicating SRS availability
## NOTES

## RELATED LINKS
