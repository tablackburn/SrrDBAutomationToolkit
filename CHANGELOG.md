# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.2] - 2025-12-29

### Fixed

- URL-encode `ReleaseName` in search queries to prevent path injection attacks
- Use `GetInvalidFileNameChars()` for comprehensive filename sanitization in `Get-SatNfo` and `Get-SatSrr`
- Fix `MaxResults` pagination logic with explicit flag to prevent unnecessary API calls

### Changed

- Optimize `List` allocation with capacity hint after first API call
- Refactor parameter mapping in `Search-SatRelease` from 64 lines to 12 lines
- Apply agent instruction guidelines: replace shorthand variable names with full words

### Improved

- Increase test coverage from 98.8% to 99.4%

## [0.2.1] - 2025-12-29

### Changed

- Made `Get-SatSrr -OutPath` optional, defaults to current directory
- Changed `Get-SatNfo -Download` to save files to disk instead of outputting to console

## [0.2.0] - 2025-12-28

### Added

- Additional search filters for `Search-SatRelease`
- Retry logic with exponential backoff for API calls

## [0.1.0] - 2025-12-27

### Added

- Initial release of SrrDBAutomationToolkit
- `Search-SatRelease` - Search for releases with filters (query, category, group, IMDB, NFO, SRS, date)
- `Get-SatRelease` - Get detailed release information
- `Get-SatNfo` - Get NFO file info and download NFO content
- `Get-SatImdb` - Get IMDB information linked to releases
- `Get-SatSrr` - Download SRR files
- Pipeline support for all commands
- Comprehensive Pester test suite
- Full comment-based help documentation

[0.2.2]: https://github.com/tablackburn/SrrDBAutomationToolkit/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/tablackburn/SrrDBAutomationToolkit/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/tablackburn/SrrDBAutomationToolkit/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/tablackburn/SrrDBAutomationToolkit/releases/tag/v0.1.0
