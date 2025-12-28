# Repository-Specific Instructions

These instructions apply specifically to the SrrDBAutomationToolkit repository.

## Project Overview

This is a PowerShell module that wraps the [srrDB API](https://api.srrdb.com/v1/) for interacting
with the scene release database. The module provides cmdlets for searching releases, retrieving
NFO files, downloading SRR files, and looking up IMDB information.

## Build System

This project uses **PowerShellBuild** with psake for build automation:

- `.\build.ps1 -Bootstrap` - Install build dependencies
- `.\build.ps1 -Task Test` - Run Pester tests
- `.\build.ps1 -Task Build` - Build the module (generates help docs)

The build process uses PlatyPS to generate MAML help from markdown files in `docs/en-US/`.

## Directory Structure

| Path | Purpose |
|------|---------|
| `SrrDBAutomationToolkit/` | Source module code |
| `SrrDBAutomationToolkit/Public/` | Exported cmdlets |
| `SrrDBAutomationToolkit/Private/` | Internal helper functions |
| `Output/` | Build output (gitignored) |
| `docs/en-US/` | PlatyPS-generated markdown help |
| `tests/` | Pester test files |

## Important Guidelines

### Do Not Edit Generated Files

The markdown files in `docs/en-US/` are **auto-generated** by PlatyPS during the build process.
Do not manually edit these files. Instead:

1. Update the comment-based help in the source `.ps1` files
2. Run `.\build.ps1 -Task Build` to regenerate the documentation

### API Responsibility

When working with srrDB API calls, follow their guidelines: "Use but don't scrape." Implement
appropriate rate limiting and retry logic with exponential backoff.

### Documentation Tone

The README.md uses playful nautical language and references to "Linux ISOs" as an in-joke for
the target audience. Maintain this tone in user-facing documentation while keeping technical
documentation (cmdlet help, code comments) professional.

### Testing Requirements

- Unit tests go in `tests/Unit/`
- Integration tests go in `tests/Integration/`
- Integration tests make real API calls - use them sparingly
- All public cmdlets must have corresponding help tests (validated by `tests/Help.tests.ps1`)

### Cmdlet Naming Convention

All cmdlets use the `Sat` noun prefix (short for "Srr Automation Toolkit"):

- `Search-SatRelease`
- `Get-SatRelease`
- `Get-SatNfo`
- `Get-SatImdb`
- `Get-SatSrr`

New cmdlets should follow this pattern: `Verb-SatNoun`
