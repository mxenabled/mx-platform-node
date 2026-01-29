# Adding a New API Version to mx-platform-node

**Document Purpose**: Step-by-step guide for adding support for a new API version (e.g., `v20300101`) to the mx-platform-node repository.

**Last Updated**: January 28, 2026  
**Time to Complete**: 30-45 minutes  
**Prerequisites**: Familiarity with the multi-version architecture (see [Multi-Version-SDK-Flow.md](Multi-Version-SDK-Flow.md))

---

## Overview

When the OpenAPI repository releases a new API version, adding it to mx-platform-node requires four main steps:
1. Create a configuration file for the new API version
2. Update workflow files to include the new version in all required locations
3. Update documentation to reflect the new version
4. Verify the setup works correctly

The process is designed to be self-contained and non-breaking—existing versions continue to work regardless of whether you've added new ones.

**Prerequisite**: The new API version OAS file must exist in the [openapi repository](https://github.com/mxenabled/openapi) following the existing file naming convention: `openapi/v<VERSION>.yml` (e.g., `openapi/v20300101.yml`).

---

## Step 1: Create Configuration File

Create a new configuration file for your API version: `openapi/config-v20300101.yml`

```yaml
---
generatorName: typescript-axios
npmName: mx-platform-node
npmVersion: 4.0.0          # New major version for new API
apiVersion: v20300101
supportsES6: true
.openapi-generator-ignore: true
```

**Critical: Semantic Versioning Rule**

Major version must be unique and increment sequentially:
- v20111101 API → npm version 2.x.x
- v20250224 API → npm version 3.x.x
- v20300101 API → npm version 4.x.x (NEW)

This ensures moving between major versions always indicates an API change.

**File Locations and Naming**

- **Config file**: `openapi/config-v<API_VERSION>.yml`
- **Generated directory**: `v<API_VERSION>/` (created automatically on first generation)
- **API version format**: Must match spec files in openapi repository (e.g., `v20300101.yml`)

### Verify the Config File

Test that your config file is valid YAML and contains all required fields:
```bash
ruby -e "require 'yaml'; puts YAML.load(File.read('openapi/config-v20300101.yml'))"
```

Should output valid parsed YAML without errors.

---

## Step 2: Update Workflow Files

You must update three workflow files in the `.github/workflows/` directory. Each file has multiple locations that require the new version entry.

### 2.1 Update generate.yml

This workflow enables manual SDK generation via GitHub Actions.

**Location 1: Workflow dispatch options**

In the `on.workflow_dispatch.inputs.api_version.options` section, add the new version to the dropdown list:

```yaml
api_version:
  description: "API version to generate"
  required: true
  type: choice
  options:
    - v20111101
    - v20250224
    - v20300101    # NEW
```

**Location 2: Update ConfigValidator**

In `.github/config_validator.rb`, add your new version to the `SUPPORTED_VERSIONS` mapping:

```ruby
class ConfigValidator
  SUPPORTED_VERSIONS = {
    "v20111101" => 2,  # Major version must be 2
    "v20250224" => 3,  # Major version must be 3
    "v20300101" => 4   # Major version must be 4 (NEW)
  }.freeze
  # ... rest of class unchanged
end
```

The `ConfigValidator` automatically validates that:
- The API version is in `SUPPORTED_VERSIONS`
- The major version in your config file matches the expected value (e.g., v20300101 → major version 4)
- The config file syntax is valid YAML
- The file exists at the specified path

**No workflow changes needed** — the existing validation step in `generate.yml` calls `ConfigValidator` with your new version, and it automatically validates using the updated mapping.

### 2.2 Update openapi-generate-and-push.yml

This workflow is automatically triggered by the OpenAPI repository to generate and push SDKs for all versions in parallel.

**Location 1: Version-to-config mapping**

In the `Setup` job's `Set up matrix` step, add an `elif` branch to map your new version to its config file:

```yaml
if [ "$VERSION" = "v20111101" ]; then
  CONFIG="openapi/config-v20111101.yml"
elif [ "$VERSION" = "v20250224" ]; then
  CONFIG="openapi/config-v20250224.yml"
elif [ "$VERSION" = "v20300101" ]; then
  CONFIG="openapi/config-v20300101.yml"
fi
```

This dynamically builds the matrix that determines which config file each version uses during generation.

**Location 2: Add version to ChangelogManager priority order**

In `.github/changelog_manager.rb`, add your new version to the `API_VERSION_ORDER` array in the correct priority position (newest API version first):

```ruby
API_VERSION_ORDER = ['v20300101', 'v20250224', 'v20111101'].freeze
```

This ensures when multiple versions are generated, changelog entries appear in order by API version (newest first), following standard changelog conventions.

**No other changes needed for CHANGELOG updates** — the `ChangelogManager` class automatically:
- Reads version numbers from each API's `package.json`
- Validates versions are in `API_VERSION_ORDER`
- Extracts date ranges from existing entries
- Inserts properly formatted entries at the top of the changelog

### 2.3 Update on-push-master.yml

This workflow automatically triggers publish and release jobs when version directories are pushed to master. Since individual version jobs use conditional `if` statements based on path changes, you need to add new conditional jobs for your new version.

**Location 1: Path trigger**

In the `on.push.paths` section, add a new path for your version:

```yaml
on:
  push:
    branches: [master]
    paths:
      - 'v20111101/**'
      - 'v20250224/**'
      - 'v20300101/**'    # NEW
```

This ensures the workflow triggers when changes to your version directory are pushed to master.

**Location 2: Add publish job for new version**

Add a new publish job for your version (copy and modify the existing v20250224 jobs):

```yaml
publish-v20300101:
  runs-on: ubuntu-latest
  needs: [check-skip-publish, gate-v20250224-complete]    # Gate waits for previous version
  if: needs.check-skip-publish.outputs.skip_publish == 'false' && contains(github.event.head_commit.modified, 'v20300101')
  uses: ./.github/workflows/publish.yml@master
  with:
    version_directory: v20300101
  secrets: inherit
```

**Location 3: Add release job for new version**

Add a new release job for your version:

```yaml
release-v20300101:
  runs-on: ubuntu-latest
  needs: [check-skip-publish, publish-v20300101]
  if: needs.check-skip-publish.outputs.skip_publish == 'false' && contains(github.event.head_commit.modified, 'v20300101')
  uses: ./.github/workflows/release.yml@master
  with:
    version_directory: v20300101
  secrets: inherit
```

**Location 4: Add gate job for previous version**

Add a new gate job after the previous version's release to handle serial ordering:

```yaml
gate-v20250224-complete:
  runs-on: ubuntu-latest
  needs: [check-skip-publish, release-v20250224]
  if: always() && needs.check-skip-publish.outputs.skip_publish == 'false'
  steps:
    - name: Gate complete - ready for v20300101
      run: echo "v20250224 release workflow complete (or skipped)"
```

**Important Notes**:
- Each publish job depends on the **previous version's gate job** to maintain serial ordering
- Each release job depends on its corresponding publish job
- Gate jobs use the `always()` condition so they run even when intermediate jobs are skipped
- This prevents npm registry race conditions and ensures correct behavior whether one or multiple versions are modified

### 2.4 Verify Workflow Syntax

Check that your YAML is valid for all three modified files:

```bash
ruby -e "require 'yaml'; puts YAML.load(File.read('.github/workflows/generate.yml'))"
ruby -e "require 'yaml'; puts YAML.load(File.read('.github/workflows/openapi-generate-and-push.yml'))"
ruby -e "require 'yaml'; puts YAML.load(File.read('.github/workflows/on-push-master.yml'))"
```

All commands should output valid parsed YAML without errors.

---

## Step 3: Update Documentation

Documentation files need to be updated to reflect the new API version availability. These files provide visibility to users about which versions are available and how to migrate between them.

### 3.1 Update Root README.md

Update the API versions table to include your new version.

**Location: API versions table**

In the "Which API Version Do You Need?" section, add a row for your version:

```markdown
| API Version | npm Package | Documentation |
|---|---|---|
| **v20111101** | `mx-platform-node@^2` | [v20111101 SDK README](./v20111101/README.md) |
| **v20250224** | `mx-platform-node@^3` | [v20250224 SDK README](./v20250224/README.md) |
| **v20300101** | `mx-platform-node@^4` | [v20300101 SDK README](./v20300101/README.md) |
```

**Location: Installation section**

Also add an installation example for your version in the Installation section:

```bash
# For v20300101 API
npm install mx-platform-node@^4
```

### 3.2 Update MIGRATION.md

Add a new migration section for users upgrading from the previous API version to your new version.

**New section to add** (before the existing v20111101→v20250224 migration section):

```markdown
## Upgrading from v20250224 (v3.x) to v20300101 (v4.x)

The v20300101 API is now available, and v4.0.0 of this SDK provides support as an independent major version.

### Installation

The two API versions are published as separate major versions of the same npm package:

**For v20250224 API:**
```bash
npm install mx-platform-node@^3
```

**For v20300101 API:**
```bash
npm install mx-platform-node@^4
```

### Migration Path

1. **Review API Changes**: Consult the [MX Platform API Migration Guide](https://docs.mx.com/api-reference/platform-api/overview/migration) for breaking changes and new features
2. **Update Package**: Update your `package.json` to use `mx-platform-node@^4`
3. **Update Imports**: Both APIs have similar structure, but review type definitions for any breaking changes
4. **Run Tests**: Validate your code works with the new SDK version
5. **Deploy**: Update production once validated

### Benefits of TypeScript

Since this is a TypeScript SDK, the compiler will help catch most compatibility issues at compile time when you update to v4.x.
```

### 3.3 Update README.mustache Template

In `openapi/templates/README.mustache`, update the "Available API Versions" section to include your version.

**Location: Available API Versions section**

Add a new line for your version in the list:

```markdown
## Available API Versions

- **{{npmName}}@2.x.x** - [v20111101 API](https://docs.mx.com/api-reference/platform-api/v20111101/reference/mx-platform-api/)
- **{{npmName}}@3.x.x** - [v20250224 API](https://docs.mx.com/api-reference/platform-api/reference/mx-platform-api/)
- **{{npmName}}@4.x.x** - [v20300101 API](https://docs.mx.com/api-reference/platform-api/reference/mx-platform-api/)
```

**Note**: The template uses Mustache variables (`{{npmName}}`), so it will automatically populate the correct package name. This list is static and won't change based on the variables, so you must manually update it.

---

## Step 4: Verify the Setup

### 4.1 Manual Generation Test

Test that your new version can be generated manually before waiting for upstream changes.

Run the `generate.yml` workflow manually:
1. Go to GitHub Actions → `generate.yml`
2. Click "Run workflow"
3. **api_version**: Select `v20300101` (should appear in dropdown)
4. **version_bump**: Select `skip` (for testing, no version bump)
5. Click "Run workflow"

**Expected Results**:
- Workflow completes successfully
- A new PR is created with branch name: `openapi-generator-v20300101-4.0.0`
- PR contains generated SDK files in new `v20300101/` directory

### 4.2 Verify Generated Structure

Once PR is created (before merging), verify the generated files:

```bash
# Check directory was created
ls -la v20300101/

# Verify package.json has correct version
cat v20300101/package.json | grep -A 2 '"version"'

# Should show:
# "version": "4.0.0",
# "apiVersion": "v20300101",
```

### 4.3 Check npm Package Metadata

The generated `package.json` should have:

```json
{
  "name": "mx-platform-node",
  "version": "4.0.0",
  "description": "MX Platform Node.js SDK (v20300101 API)",
  "apiVersion": "v20300101"
}
```

This ensures npm registry will show the correct API version in the package description.

### 4.4 Verify on-push-master.yml Would Trigger

Check that your path trigger configuration is correct:

```bash
# This confirms the path syntax is valid
git status --porcelain | grep "v20300101/" 
```

After merging the PR, pushing to master with changes in `v20300101/` should automatically trigger `on-push-master.yml`.

---

## Checklist

Use this checklist to verify you've completed all steps:

- [ ] Confirmed new API version OAS file exists in openapi repository at `openapi/v20300101.yml`
- [ ] Created `openapi/config-v20300101.yml` with correct syntax
- [ ] Major version in config is unique and sequential (4.0.0 for v20300101)
- [ ] Updated `.github/workflows/generate.yml` with new version in dropdown options
- [ ] Updated `.github/config_validator.rb` with new version in `SUPPORTED_VERSIONS` mapping
- [ ] Updated `.github/workflows/openapi-generate-and-push.yml` with version-to-config mapping in Setup job
- [ ] Updated `.github/changelog_manager.rb` with new version in `API_VERSION_ORDER` array
- [ ] Updated `.github/workflows/on-push-master.yml` path triggers with `v20300101/**`
- [ ] Updated `.github/workflows/on-push-master.yml` with new publish job for v20300101
- [ ] Updated `.github/workflows/on-push-master.yml` with new release job for v20300101
- [ ] Updated `.github/workflows/on-push-master.yml` with new gate job for previous version (v20250224)
- [ ] Verified workflow YAML syntax is valid for all three modified files
- [ ] Updated root `README.md` with new API version table entry
- [ ] Updated root `README.md` with installation example for new version
- [ ] Updated `MIGRATION.md` with new migration section
- [ ] Updated `openapi/templates/README.mustache` Available API Versions section
- [ ] Ran `generate.yml` manual test with new version
- [ ] Verified generated `package.json` has correct version and apiVersion
- [ ] Verified PR would be created with correct branch name format
- [ ] Merged test PR to master (or closed it if testing only)
- [ ] Confirmed no errors in existing version workflows

---

## Troubleshooting

### OAS file not found in openapi repository
**Cause**: The new API version spec file doesn't exist in the openapi repository  
**Solution**: Verify the file exists at `https://github.com/mxenabled/openapi/blob/master/openapi/v20300101.yml`

### Config file not found during generation
**Cause**: Filename doesn't match API version  
**Solution**: Verify config file is named exactly `openapi/config-v20300101.yml`

### New version doesn't appear in generate.yml dropdown
**Cause**: Config file not added to workflow options or YAML syntax error  
**Solution**: Verify the version is listed in the `on.workflow_dispatch.inputs.api_version.options` section and YAML syntax is valid

### Semantic versioning validation fails
**Cause**: ConfigValidator not updated with new version or major version mismatch  
**Solution**: Ensure the new version is added to `SUPPORTED_VERSIONS` in `.github/config_validator.rb` and the major version in your config file matches the expected value

### Generated version is 2.x.x or 3.x.x instead of 4.0.0
**Cause**: Wrong major version in config file  
**Solution**: Update `npmVersion: 4.0.0` in config file to use unique major version

### openapi-generate-and-push.yml doesn't recognize new version
**Cause**: Version-to-config mapping missing in Setup job, ChangelogManager not updated, or ConfigValidator not updated  
**Solution**: Verify three locations are updated: (1) version-to-config mapping in openapi-generate-and-push.yml Setup job, (2) add version to `API_VERSION_ORDER` in `changelog_manager.rb`, and (3) add version to `SUPPORTED_VERSIONS` in `config_validator.rb`

### on-push-master.yml doesn't trigger after merge
**Cause**: Path trigger syntax incorrect or matrix not updated  
**Solution**: Verify path is exactly `v20300101/**` with forward slashes and both publish and release matrix entries are present

### Existing versions break after adding new version
**Cause**: Matrix syntax error, missing conditional, or bad YAML  
**Solution**: Verify all workflow files have valid YAML syntax; test existing workflows still work

---

## Next Steps

Once verified:

1. **Commit changes**: Push config and workflow updates to a feature branch
2. **Create PR**: Get code review of workflow changes
3. **Merge PR**: Once approved, merge to master
4. **Wait for OpenAPI updates**: New version won't generate until OpenAPI repo sends it in payload
5. **Monitor first generation**: Watch the automatic `openapi-generate-and-push.yml` run when OpenAPI repo triggers it

---

## Reference

For more details on how the workflows use these configurations, see:
- [Multi-Version-SDK-Flow.md](Multi-Version-SDK-Flow.md) - Architecture overview
- [Workflow-and-Configuration-Reference.md](Workflow-and-Configuration-Reference.md) - Detailed implementation
