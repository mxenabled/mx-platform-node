# Adding a New API Version to mx-platform-node

**Document Purpose**: Step-by-step guide for adding support for a new API version (e.g., `v20300101`) to the mx-platform-node repository.

**Last Updated**: January 27, 2026  
**Time to Complete**: 30-45 minutes  
**Prerequisites**: Familiarity with the multi-version architecture (see [Multi-Version-SDK-Flow.md](Multi-Version-SDK-Flow.md))

---

## Overview

When the OpenAPI repository releases a new API version, adding it to mx-platform-node requires four main steps:
1. Create a configuration file for the new API version
2. Update workflow files to include the new version in the matrix
3. Coordinate with the OpenAPI repository on payload format
4. Verify the setup works correctly

The process is designed to be self-contained and non-breaking—existing versions continue to work regardless of whether you've added new ones.

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

### 2.1 Update on-push-master.yml

Add the new version to the matrix strategy:

**File**: `.github/workflows/on-push-master.yml`

**Find this section**:
```yaml
strategy:
  matrix:
    version:
      - api_version: v20111101
        npm_version: 2
      - api_version: v20250224
        npm_version: 3
```

**Add new entry**:
```yaml
strategy:
  matrix:
    version:
      - api_version: v20111101
        npm_version: 2
      - api_version: v20250224
        npm_version: 3
      - api_version: v20300101    # NEW
        npm_version: 4
```

### 2.2 Update Path Triggers

In the same file, add the new path trigger:

**Find this section**:
```yaml
on:
  push:
    branches: [master]
    paths:
      - 'v20111101/**'
      - 'v20250224/**'
```

**Add new path**:
```yaml
on:
  push:
    branches: [master]
    paths:
      - 'v20111101/**'
      - 'v20250224/**'
      - 'v20300101/**'           # NEW
```

This ensures that when changes to `v20300101/` are pushed to master, the publish and release workflows automatically trigger.

### 2.3 Verify Workflow Syntax

Check that your YAML is valid:
```bash
ruby -e "require 'yaml'; puts YAML.load(File.read('.github/workflows/on-push-master.yml'))"
```

---

## Step 3: Coordinate with OpenAPI Repository

The OpenAPI repository must be updated to send the new API version in the `repository_dispatch` event payload.

### What Needs to Change in openapi repo

When openapi repository wants to trigger generation for the new version, it should send:

```json
{
  "api_versions": "v20111101,v20250224,v20300101"
}
```

**Example curl command** (what openapi repo would use):
```bash
curl -X POST \
  https://api.github.com/repos/mxenabled/mx-platform-node/dispatches \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d '{
    "event_type": "generate_sdk",
    "client_payload": {
      "api_versions": "v20111101,v20250224,v20300101"
    }
  }'
```

### Backward Compatibility

If the OpenAPI repository doesn't send the new version in the payload:
- `generate_publish_release.yml` defaults to `v20111101` only
- Existing versions continue to work unchanged
- New version won't generate until explicitly included in the payload

This is intentional—allows phased rollout without breaking existing workflows.

### Transition Plan

**Phase 1**: New config exists but openapi repo doesn't send the version
- System works with v20111101 and v20250224 only
- New version `v20300101/` directory doesn't get created
- No errors or issues

**Phase 2**: OpenAPI repo updated to send new version
- Next `generate_publish_release.yml` run includes all three versions
- `v20300101/` directory created automatically
- All three versions published to npm in parallel

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

- [ ] Created `openapi/config-v20300101.yml` with correct syntax
- [ ] Major version in config is unique and sequential (4.0.0 for v20300101)
- [ ] Updated `.github/workflows/on-push-master.yml` matrix with new version
- [ ] Updated `.github/workflows/on-push-master.yml` paths with `v20300101/**`
- [ ] Verified workflow YAML syntax is valid
- [ ] Coordinated with OpenAPI repository on payload changes
- [ ] Ran `generate.yml` manual test with new version
- [ ] Verified generated `package.json` has correct version and apiVersion
- [ ] Verified PR would be created with correct branch name format
- [ ] Merged test PR to master (or closed it if testing only)
- [ ] Confirmed no errors in existing version workflows

---

## Troubleshooting

### Config file not found during generation
**Cause**: Filename doesn't match API version  
**Solution**: Verify config file is named exactly `openapi/config-v20300101.yml`

### New version doesn't appear in generate.yml dropdown
**Cause**: Config file syntax error or not recognized  
**Solution**: Verify YAML syntax with `ruby -e "require 'yaml'; puts YAML.load(File.read('openapi/config-v20300101.yml'))"`

### Generated version is 2.x.x or 3.x.x instead of 4.0.0
**Cause**: Wrong major version in config file  
**Solution**: Update `npmVersion: 4.0.0` in config file to use unique major version

### on-push-master.yml doesn't trigger after merge
**Cause**: Path trigger syntax incorrect  
**Solution**: Verify path is exactly `v20300101/**` with forward slashes

### Existing versions break after adding new version
**Cause**: Matrix syntax error or bad YAML  
**Solution**: Verify on-push-master.yml YAML is valid; test existing workflows still work

---

## Next Steps

Once verified:

1. **Commit changes**: Push config and workflow updates to a feature branch
2. **Create PR**: Get code review of workflow changes
3. **Merge PR**: Once approved, merge to master
4. **Wait for OpenAPI updates**: New version won't generate until OpenAPI repo sends it in payload
5. **Monitor first generation**: Watch the automatic `generate_publish_release.yml` run when OpenAPI repo triggers it

---

## Reference

For more details on how the workflows use these configurations, see:
- [Multi-Version-SDK-Flow.md](Multi-Version-SDK-Flow.md) - Architecture overview
- [Workflow-and-Configuration-Reference.md](Workflow-and-Configuration-Reference.md) - Detailed implementation
