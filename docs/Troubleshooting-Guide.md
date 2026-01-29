# Troubleshooting Guide

**Document Purpose**: Quick reference for diagnosing and fixing issues in the multi-version SDK generation, publishing, and release workflows.

**Last Updated**: January 28, 2026  
**Audience**: Developers debugging workflow failures

---

## Quick Diagnosis

### No SDK Generated
Check in this order:
1. Is the OpenAPI spec file accessible?
2. Does the config file exist for that API version?
3. Are there syntax errors in the config file?

### SDK Generated But Not Published
Check in this order:
1. Did the commit reach master successfully?
2. Is `NPM_AUTH_TOKEN` secret valid?
3. Did the path filter (`v20111101/**`, etc.) match the changes?

### SDK Generated and Published But Release Not Created
Check in this order:
1. Did publish step complete successfully?
2. Does the release tag already exist?
3. Does `GITHUB_TOKEN` have release creation permissions?

---

## Common Issues and Solutions

### Generate Workflow: Configuration Validation Fails

The `generate.yml` and `openapi-generate-and-push.yml` workflows run configuration validation before SDK generation. If validation fails, the workflow stops immediately to prevent invalid configurations from generating code.

**Validator**: `.github/config_validator.rb`

Validation checks (in order):
1. API version is supported (v20111101 or v20250224)
2. Config file exists at specified path
3. Config file contains valid YAML
4. Major version in config matches API version requirement

---

### Generate Workflow: Config File Not Found

**Error Message**:
```
Error: Config file not found: openapi/config-v20111101.yml
```

**Causes**:
- Config file doesn't exist for selected API version
- Filename typo or wrong path
- API version not yet configured

**Solutions**:
1. Verify file exists: `ls -la openapi/config-v*.yml`
2. Check filename matches API version exactly
3. For new API versions, create config file first (see [Adding-a-New-API-Version.md](Adding-a-New-API-Version.md))

---

### Generate Workflow: Semantic Versioning Validation Fails

**Error Message**:
```
Error: Invalid npm version for API v20250224
Expected: 3.x.x
Got: 2.0.0
```

**Cause**: Major version in config doesn't match API version

**Semantic Versioning Rule**:
- v20111101 API must use `npmVersion: 2.x.x`
- v20250224 API must use `npmVersion: 3.x.x`
- New APIs must use next sequential major version

**Solution**: Update config file with correct major version
```yaml
---
npmName: mx-platform-node
npmVersion: 3.0.0          # Must start with 3 for v20250224
apiVersion: v20250224
```

---

### Generate Workflow: Config File Syntax Error

**Error Message**:
```
YAML syntax error in openapi/config-v20111101.yml
```

**Common Issues**:
- Incorrect indentation (YAML is whitespace-sensitive)
- Missing quotes around values with special characters
- Trailing spaces after values
- Invalid field names

**How to Test**:
```bash
ruby -e "require 'yaml'; puts YAML.load(File.read('openapi/config-v20111101.yml'))"
```

If this errors, your YAML syntax is wrong.

**Solution**: Fix YAML syntax and re-test
```yaml
---
generatorName: typescript-axios    # Must start with ---
npmName: mx-platform-node
npmVersion: 2.0.0
apiVersion: v20111101
supportsES6: true
.openapi-generator-ignore: true
```

---

### Publish Fails: NPM Auth Token Invalid

**Error Message**:
```
npm ERR! 401 Unauthorized
npm ERR! need auth 401 Unauthorized - PUT https://registry.npmjs.org/mx-platform-node
```

**Causes**:
- `NPM_AUTH_TOKEN` secret expired or revoked
- Token doesn't have publish permissions for `mx-platform-node`
- Token was deleted from GitHub repository secrets
- Wrong npm registry configured

**Solutions**:
1. Verify token exists: Go to GitHub repo → Settings → Secrets and variables → Actions → Look for `NPM_AUTH_TOKEN`
2. If missing or expired, generate new token:
   - Log into npm.js as maintainer
   - Create new "Publish" scope token (not Read-only)
   - Copy full token value
   - Update secret in GitHub repository
3. Verify token has permissions for `mx-platform-node` package
4. Wait 5 minutes after updating secret before retrying

---

### Publish Fails: Version Already Published

**Error Message**:
```
npm ERR! 403 Forbidden - PUT https://registry.npmjs.org/mx-platform-node/2.0.5
You cannot publish over the previously published version 2.0.5
```

**Cause**: Version already exists on npm registry

**Why This Happens**:
- SDK was already published with this version number
- Version bump didn't increment (check `version.rb` output)
- Wrong version directory being published

**Solutions**:
1. If intentional, increment version and regenerate:
   ```bash
   ruby .github/version.rb patch openapi/config-v20111101.yml
   ```
2. If accidental duplicate: 
   - Check `openapi/config-v20111101.yml` has next sequential version
   - Run generate workflow again to create PR with new version
   - Merge PR to trigger publish with correct version

---

### Release Not Created After Publish

**Error Message**:
```
gh release create: error: failed to create release
fatal: A release with this tag already exists
```

**Causes**:
- Release tag already exists (e.g., `v2.0.1`)
- `GITHUB_TOKEN` lacks release creation permissions
- Typo in tag name

**Solutions**:
1. Check if release already exists:
   ```bash
   git tag -l | grep v2.0.1
   ```
2. If release exists but workflow failed, delete it:
   - Go to GitHub repo → Releases → Find the release
   - Click "Delete" on the release
   - Re-run the release workflow
3. Verify `GITHUB_TOKEN` has release creation permissions (usually auto-provided by GitHub)
4. Check that version in `package.json` matches tag format (`v2.0.1`, not `2.0.1`)

---

### Both Versions Publish When Only One Should

**Scenario**: Merged a PR for v20111101 only, but both v20111101 and v20250224 published

**Causes**:
- Changes were made to both `v20111101/` and `v20250224/` directories
- Unintended changes to both directories were committed
- Path filter in `on-push-master.yml` has wrong syntax

**Solutions**:
1. Review what changed in the merged PR:
   ```bash
   git log --oneline -n 5 | head -1
   git show <commit-hash> --name-status | grep -E "v20111101|v20250224"
   ```
2. If only one version should have changed:
   - Revert the commit
   - Fix the unintended changes
   - Create a new PR with only the intended changes
3. If both versions should have changed:
   - This is correct behavior (both path filters matched)
   - Both versions published as expected

---

### Only One Version Doesn't Publish When Only That Version Changed

**Symptom**: Merged a PR that only modified `v20250224/` files, but the publish job didn't run

**Expected Behavior**: `publish-v20250224` should run when only v20250224 is modified

**Root Cause**: Previous versions of the workflow had a dependency chain that broke when intermediate jobs were skipped. This has been fixed with the gate job pattern.

**Current Implementation** (uses gate job pattern):
- `gate-v20111101-complete` uses GitHub Actions `always()` condition
- This job runs even when v20111101 jobs are skipped
- It unblocks downstream v20250224 jobs
- Result: Publishing works correctly whether one or both versions are modified

**If You're Still Seeing This Issue**:
1. Verify you have the latest `on-push-master.yml`:
   ```bash
   grep -A 3 "gate-v20111101-complete" .github/workflows/on-push-master.yml
   ```
2. Confirm the gate job uses `always()` condition:
   ```yaml
   gate-v20111101-complete:
     if: always() && needs.check-skip-publish.outputs.skip_publish == 'false'
   ```
3. Ensure `publish-v20250224` depends on the gate job:
   ```yaml
   publish-v20250224:
     needs: [check-skip-publish, gate-v20111101-complete]
   ```
4. If not present, update workflow from latest template

**Technical Details**: See [Workflow-and-Configuration-Reference.md](Workflow-and-Configuration-Reference.md#step-3-gate-job---unblock-v20250224-publishing) for full gate job implementation details.

---

### Generation Produces Stale Spec Files

**Symptom**: Generated SDK doesn't include changes that were in the OpenAPI spec

**Cause**: GitHub's raw.githubusercontent.com CDN cached the old file for 5 minutes

**Why This Happens**:
- OpenAPI repo commits spec change at 2:00 PM
- Repository dispatch sent immediately at 2:01 PM
- Workflow runs at 2:02 PM but CDN still has 2:00 PM version
- SDK generated from stale spec

**Solution**: Already implemented in `openapi-generate-and-push.yml`
- Uses commit SHA in spec URL: `raw.githubusercontent.com/mxenabled/openapi/<commit-sha>/openapi/v20111101.yml`
- Commit SHA bypasses CDN and guarantees exact spec version
- Nothing to do—this is automatic

**Manual Generation Note**: `generate.yml` uses `master` branch reference (not commit SHA) because developer controls timing and doesn't have CDN race condition concern.

---

### Workflow Not Triggering on Push

**Symptom**: Merged a PR with changes to `v20111101/` directory, but `on-push-master.yml` didn't run

**Causes**:
- Path filter in `on-push-master.yml` has syntax error or wrong path
- Changes were not actually in the version directory
- Commit was made to wrong branch
- Workflow file has syntax error

**Solutions**:
1. Verify path filter syntax is correct:
   ```yaml
   on:
     push:
       branches: [master]
       paths:
         - 'v20111101/**'     # Correct format
         - 'v20250224/**'
   ```
2. Check what files were actually changed:
   ```bash
   git diff HEAD~1..HEAD --name-only | grep -E "v20111101|v20250224"
   ```
3. Verify commit was to `master` branch:
   ```bash
   git log --oneline -n 1
   git branch -r --contains HEAD
   ```
4. Check `on-push-master.yml` syntax:
   ```bash
   ruby -e "require 'yaml'; puts YAML.load(File.read('.github/workflows/on-push-master.yml'))"
   ```

---

### Skip-Publish Flag Not Working

**Symptom**: Added `[skip-publish]` to commit message but workflow still published

**Causes**:
- Flag syntax wrong (case-sensitive, needs brackets)
- Flag in PR title/body instead of commit message
- Commit message doesn't include the flag

**Solution**: Commit message must include exact text `[skip-publish]`
```bash
# Correct
git commit -m "Migrate SDK structure [skip-publish]"

# Wrong - will not work
git commit -m "Migrate SDK structure [SKIP-PUBLISH]"
git commit -m "Migrate SDK structure (skip-publish)"
git commit -m "Migrate SDK structure skip-publish"
```

---

### Version.rb Script Errors

#### Error: "Version directory parameter required"
```
Error: Version directory parameter required. Usage: ruby clean.rb <version_dir>
```

**Cause**: `clean.rb` called without version directory argument

**Solution**: Always provide version directory
```bash
ruby .github/clean.rb v20111101    # Correct
ruby .github/clean.rb              # Wrong - missing parameter
```

#### Error: "Invalid version bump type"
```
Error: Invalid version bump type: major. Supported: 'minor' or 'patch'
```

**Cause**: Tried to use `major` option (not allowed for semantic versioning)

**Solution**: Use only `minor` or `patch`
```bash
ruby .github/version.rb patch openapi/config-v20111101.yml      # Correct
ruby .github/version.rb major openapi/config-v20111101.yml      # Wrong - major not allowed
```

#### Error: "Config file not found"
```
Error: Config file not found: openapi/config-invalid.yml
```

**Cause**: Config file path doesn't exist

**Solution**: Verify file path and spelling
```bash
ls -la openapi/config-v*.yml           # List valid files
ruby .github/version.rb patch openapi/config-v20111101.yml      # Use correct path
```

---

### GitHub Actions Workflow Syntax Errors

**Error Message** (in GitHub Actions UI):
```
Invalid workflow file
```

**Common Causes**:
- YAML indentation error
- Invalid GitHub Actions syntax
- Missing required fields
- Circular job dependencies

**How to Debug**:
1. Go to GitHub repo → Actions → Select failed workflow
2. Click on the workflow run
3. Look for error message at top (usually shows line number)
4. Check YAML syntax locally:
   ```bash
   ruby -e "require 'yaml'; YAML.load_file('.github/workflows/on-push-master.yml')"
   ```

**Most Common Fix**: Indentation
- GitHub Actions workflows are YAML files
- Indentation must be consistent (usually 2 spaces)
- Use an editor with YAML validation

---

## Getting Help

If you encounter an issue not covered above:

1. **Check workflow logs**: Go to GitHub repo → Actions → Failed workflow → Click run → Expand failed step
2. **Review error message**: Look for specific file names, line numbers, or error codes
3. **Check recent changes**: Did a recent PR change workflows or configs?
4. **Test locally**: Try running Ruby scripts manually to verify syntax
5. **Ask the team**: Reference the error message and steps to reproduce

---

## Reference

- [Multi-Version-SDK-Flow.md](Multi-Version-SDK-Flow.md) - Architecture overview
- [Workflow-and-Configuration-Reference.md](Workflow-and-Configuration-Reference.md) - Detailed implementation
- [Adding-a-New-API-Version.md](Adding-a-New-API-Version.md) - Step-by-step guide for new versions
