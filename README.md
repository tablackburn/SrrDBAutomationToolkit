# SrrDBAutomationToolkit

[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/SrrDBAutomationToolkit)](https://www.powershellgallery.com/packages/SrrDBAutomationToolkit/)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/SrrDBAutomationToolkit)](https://www.powershellgallery.com/packages/SrrDBAutomationToolkit/)
[![CI](https://img.shields.io/github/actions/workflow/status/tablackburn/SrrDBAutomationToolkit/CI.yaml?branch=main)](https://github.com/tablackburn/SrrDBAutomationToolkit/actions/workflows/CI.yaml)
![Platform](https://img.shields.io/powershellgallery/p/SrrDBAutomationToolkit)
[![AI Assisted](https://img.shields.io/badge/AI-Assisted-blue)](https://claude.ai)

A PowerShell module for interacting with [srrdb.com](https://www.srrdb.com), the scene release database. Whether you're cataloging your extensive collection of Linux ISOs or simply navigating the high seas of digital preservation, this toolkit has you covered.

> **Legal Notice:** This module provides metadata lookup capabilities only. It **cannot** be used to download, distribute, or acquire copyrighted material. srrDB is a database of release information and file verification data - not a source of actual content. Please respect intellectual property laws in your jurisdiction.

## Features

- Search scene releases with various filters (category, group, IMDB, etc.)
- Retrieve detailed release information
- Get NFO file content and download NFO files
- Look up IMDB information linked to releases
- Download SRR (ReScene) files

## Installation

### From Source

```powershell
git clone https://github.com/tablackburn/SrrDBAutomationToolkit.git
cd SrrDBAutomationToolkit
Import-Module .\SrrDBAutomationToolkit\SrrDBAutomationToolkit.psd1
```

### From PowerShell Gallery (Future)

```powershell
Install-Module -Name SrrDBAutomationToolkit
```

## Quick Start

```powershell
# Import the module
Import-Module SrrDBAutomationToolkit

# Search for releases
Search-SatRelease -Query "Inception" -Category "x264"

# Get release details
Get-SatRelease -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS"

# Get NFO content
Get-SatNfo -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS" -Download

# Get IMDB information
Get-SatImdb -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS"

# Download SRR file
Get-SatSrr -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS" -OutPath "C:\SRR"
```

## Commands

| Command | Description |
|---------|-------------|
| `Search-SatRelease` | Search for releases in the srrDB database |
| `Get-SatRelease` | Get detailed information about a specific release |
| `Get-SatNfo` | Get NFO file information or download NFO content |
| `Get-SatImdb` | Get IMDB information linked to a release |
| `Get-SatSrr` | Download the SRR file for a release |

## Search Examples

### Basic Search

```powershell
# Simple text search
Search-SatRelease -Query "Harry Potter"

# Search with category filter
Search-SatRelease -Query "Inception" -Category "x264"

# Search with NFO filter
Search-SatRelease -Query "Avatar" -HasNfo
```

### Advanced Search

```powershell
# Search by release group
Search-SatRelease -Query "Matrix" -Group "SPARKS"

# Search by IMDB ID
Search-SatRelease -ImdbId "tt1375666"

# Exact release name lookup (faster)
Search-SatRelease -ReleaseName "Inception.2010.1080p.BluRay.x264-SPARKS"

# Combine multiple filters
Search-SatRelease -Query "Inception" -Category "x264" -HasNfo -Group "SPARKS"
```

### Pipeline Usage

```powershell
# Search and get full details
Search-SatRelease -Query "Inception" | Get-SatRelease

# Search and download all NFOs
Search-SatRelease -Query "Matrix" -HasNfo | Get-SatNfo -OutPath "C:\NFOs"

# Search and get IMDB info
Search-SatRelease -ImdbId "tt0133093" | Get-SatImdb
```

## Categories

The following categories are supported for filtering:

| Category | Description |
|----------|-------------|
| `tv` | TV shows |
| `xvid` | XviD releases |
| `x264` | x264 releases |
| `dvdr` | DVD-R releases |
| `xxx` | Adult content |
| `pc` | PC software/games |
| `music` | Music releases |
| `flac` | FLAC audio |
| `mp3` | MP3 audio |
| `games` | Games |
| `apps` | Applications |

See `Get-Help Search-SatRelease -Parameter Category` for the full list.

## Building and Testing

### Prerequisites

```powershell
# Bootstrap build dependencies
.\build.ps1 -Bootstrap
```

### Run Tests

```powershell
.\build.ps1 -Task Test
```

### Build Module

```powershell
.\build.ps1 -Task Build
```

## API Reference

This module uses the [srrDB API v1](https://api.srrdb.com/v1/docs).

Please use the API responsibly and follow their guidelines: "Use but don't scrape." Fair winds and smooth sailing to those who respect the rules of the sea.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments


- [Claude](https://claude.ai) by Anthropic for AI-assisted development
- [srrDB](https://www.srrdb.com) for providing the API and keeping the archives of the high seas intact
- [ReScene](http://rescene.wikidot.com/) for the scene preservation project
- All the dedicated sailors cataloging their Linux ISOs for posterity
