# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-01-29

### ⚠️ BREAKING CHANGES

This is a major version bump because it targets a new API version. If you are currently using `mx-platform-node@^2`, this is a new API version (`v20250224`) with potentially significant changes. **See the [MX Platform API Migration Guide](https://docs.mx.com/api-reference/platform-api/overview/migration) for detailed API breaking changes and migration instructions.**

### Added
- Initial support for MX Platform API `v20250224`
- Published as separate major version to support independent API versions

### Changed
- This is a completely new API version (`v20250224`). Refer to the [MX Platform API changelog](https://docs.mx.com/resources/changelog/platform) for detailed API specification changes from `v20111101`

### Migration
For upgrading from `mx-platform-node@^2` (v20111101 API) to v3.x (v20250224 API):
```bash
npm install mx-platform-node@^3
```
Consult the [MX Platform API Migration Guide](https://docs.mx.com/api-reference/platform-api/overview/migration) for API-level changes, deprecations and migration steps.

## [2.0.0] - 2026-01-07 (v20111101 API)

### Changed
- **Versioning Correction:** Re-released as v2.0.0 to properly indicate breaking changes that were inadvertently introduced in v1.10.1
- No code changes from v1.12.1 - this is a versioning correction to follow semantic versioning
- Versions v1.10.1 through v1.12.1 are now deprecated on npm in favor of this properly versioned v2.0.0 release

### ⚠️ BREAKING CHANGES (from v1.10.0)

**API Class Restructure:** The unified `MxPlatformApi` class has been replaced with granular, domain-specific API classes (e.g., `UsersApi`, `MembersApi`, `AccountsApi`) to better align with the OpenAPI specification structure. This change improves code organization and maintainability but requires migration of existing code.

**Note:** This breaking change was originally introduced in v1.10.1 but should have been released as v2.0.0. If you are currently using v1.10.1 through v1.12.1, the code is functionally identical to v2.0.0.

**See [MIGRATION.md](MIGRATION.md) for detailed upgrade instructions.**

### Changed
- Restructured API classes from single `MxPlatformApi` to domain-specific classes

## [1.12.1] - 2025-11-25 (v20111101 API)

### Fixed
- Updated package template (`package.mustache`) to fix recurring dependency regression
  - axios: ^0.21.4 → ^1.6.8 (fixes CVE GHSA-wf5p-g6vw-rhxx)
  - typescript: ^3.6.4 → ^5.4.5
  - @types/node: ^12.11.5 → ^20.12.7
- Added automated validation workflow to prevent template/package.json drift

### ⚠️ DEPRECATED
This version contains breaking API changes that should have been released as v2.0.0. Please upgrade to v2.0.0 (code is functionally identical, just properly versioned).

## [1.12.0] and earlier (1.10.1 - 1.12.0) - Various dates

### ⚠️ DEPRECATED
These versions (v1.10.1 through v1.12.0) contain the breaking API restructure but were incorrectly published as minor/patch releases instead of a major version. They have been deprecated on npm in favor of v2.0.0.

**If you are on any of these versions:** Please upgrade to v2.0.0.

## [1.10.0] - 2025-11-05 (v20111101 API)

### Note
- Last stable version with unified `MxPlatformApi` class
- Upgrade from this version to v2.0.0 requires code changes (see [MIGRATION.md](MIGRATION.md))

---

**Note:** This CHANGELOG was created retroactively. For detailed version history prior to v2.0.0, please refer to the [commit history](https://github.com/mxenabled/mx-platform-node/commits/master).