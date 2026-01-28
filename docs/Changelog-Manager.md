# Changelog Manager

## Purpose

Manages automatic CHANGELOG.md updates whenever API versions are generated and published. The root CHANGELOG.md is shared across the entire project, but each API version is independently updated. This class handles extracting version information from each API's package.json and inserting properly formatted entries at the top of the changelog.

## Context

This repo supports multiple API versions (v20250224, v20111101) that are generated from OpenAPI specs and published separately. When a new version is generated, we need to:
1. Extract the new version number from that API's package.json
2. Add an entry to the root CHANGELOG.md showing this update
3. Include a date range showing what changed since the last update to that API version

The `ChangelogManager` class centralizes this logic rather than embedding it in build scripts.

## Usage

### From Command Line

```bash
# Called from GitHub Actions workflows
ruby .github/changelog_manager.rb v20250224,v20111101
```

The script uses today's date for the changelog entry and looks for existing entries to determine the date range.

### As a Ruby Class

```ruby
ChangelogManager.update('v20250224,v20111101')
ChangelogManager.update(['v20250224'])
```

## How It Works

1. Validates that the provided versions are supported (v20250224, v20111101)
2. Reads the package.json from each version to get the version number
3. Searches the existing changelog for prior entries for each API version
4. **Sorts versions by priority** (newest first, v20250224 before v20111101) so that entries with higher version numbers appear at the top of the changelog, following standard changelog conventions. This ordering is consistent regardless of the order versions are passed in.
5. Creates changelog entries with:
   - The new version number and today's date
   - A reference to the API changelog
   - A date range showing changes since the last update (if a prior entry exists)
6. Inserts new entries at the top of the changelog

### Example with Multiple Versions

When updating both versions at once:
```bash
ruby .github/changelog_manager.rb v20111101,v20250224
```

The entries are inserted in version order (v20250224 first, v20111101 second), even though v20111101 was listed first. This is because v20250224 has a higher version number (3.2.0 vs 2.5.3) and should appear at the top per changelog conventions.

Result:
```markdown
## [3.2.0] - 2025-01-28 (v20250224 API)
Updated v20250224 API specification to most current version...

## [2.5.3] - 2025-01-28 (v20111101 API)
Updated v20111101 API specification to most current version...
```

### Example Output

With a prior entry:
```markdown
## [3.2.0] - 2025-01-28 (v20250224 API)
Updated v20250224 API specification to most current version. Please check full [API changelog](https://docs.mx.com/resources/changelog/platform) for any changes made between 2025-01-15 and 2025-01-28.
```

Without a prior entry:
```markdown
## [3.2.0] - 2025-01-28 (v20250224 API)
Updated v20250224 API specification to most current version. Please check full [API changelog](https://docs.mx.com/resources/changelog/platform) for any changes.
```

## Location

- **Class**: `.github/changelog_manager.rb`
- **Tests**: `.github/spec/changelog_manager_spec.rb`
- **Fixtures**: `.github/spec/fixtures/`
