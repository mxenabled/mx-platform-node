# Workflow and Configuration Reference

**Document Purpose**: Detailed technical reference for the multi-version SDK generation, publishing, and release workflows. Covers implementation details, configuration files, and system architecture.

**Last Updated**: January 28, 2026  
**Audience**: Developers who need to understand or modify the implementation

---

## Flow 1: Automatic Multi-Version Generation (Repository Dispatch)

### Trigger
OpenAPI specifications change in the upstream `openapi` repository → Repository sends `repository_dispatch` event with optional `api_versions` payload → `openapi-generate-and-push.yml` workflow is triggered

### Backward Compatibility Model
- **No Payload (v20111101 only)**: If openapi repo sends `repository_dispatch` without `api_versions` field, defaults to generating v20111101 only
- **Single Version Payload** (`api_versions: "v20111101"`): Generates only the specified version
- **Multi-Version Payload** (`api_versions: "v20111101,v20250224"`): Generates both versions in parallel

This allows phased migration: current behavior works as-is, and when the openapi repo is ready for multi-version, no code changes are needed in mx-platform-node.

### Implementation

**Workflow**: `.github/workflows/openapi-generate-and-push.yml`

#### Step 1: Setup - Determine Versions to Generate

```yaml
env:
  VERSIONS_TO_GENERATE: ${{ github.event.client_payload.api_versions || 'v20111101' }}
```

- If `api_versions` in payload: Use specified versions (e.g., `v20111101,v20250224`)
- If no payload: Default to `v20111101` (backward-compatible single-version behavior)

#### Step 2: Generate SDKs (Matrix Execution)

**Matrix Strategy**: Each API version runs as independent matrix job in parallel

```yaml
strategy:
  matrix:
    api_version: [v20111101, v20250224]
```

**For Each Version** (e.g., v20111101):

1. **Clean Version Directory**
   - Command: `ruby .github/clean.rb v20111101`
   - Deletes previously generated SDK files from that version directory only
   - Prevents accidentally deleting unrelated version code

2. **Setup Workflow Files**
   - Copy `.openapi-generator-ignore` to version directory
   - Create directory structure for generation

3. **Bump Version**
   - Script: `ruby .github/version.rb patch openapi/config-v20111101.yml`
   - Reads `npmVersion` from config, increments, writes back
   - Example: 2.0.0 → 2.0.1 (patch) or 2.1.0 (minor)

4. **Generate SDK from OpenAPI Spec**
   - **Input Spec URL**: Version-specific with commit SHA to bypass CDN cache
   ```
   https://raw.githubusercontent.com/mxenabled/openapi/<commit-sha>/openapi/v20111101.yml
   ```
   - **Why Commit SHA**: GitHub's raw CDN caches files for 5 minutes. Without the commit SHA, a workflow triggered immediately after a spec change might pull a cached (stale) version instead of the new one. The commit SHA ensures we always use the exact spec that triggered the workflow.
   - **Output Directory**: `v20111101/` (version-specific)
   - **Configuration**: Uses version-specific config file with correct `npmVersion` and `apiVersion`
   - **Templates**: Shared templates in `./openapi/templates/` use `{{apiVersion}}` and `{{npmVersion}}` placeholders
   - **Process**:
     1. Install OpenAPI Generator CLI globally
     2. Run TypeScript-Axios generator with version-specific config
     3. Generates SDK code in version directory

5. **Copy Documentation**
   - Copy documentation files to version directory:
     - `LICENSE` → `v20111101/LICENSE`
     - `MIGRATION.md` → `v20111101/MIGRATION.md`
     - `.openapi-generator-ignore` → `v20111101/.openapi-generator-ignore`

6. **Upload Artifacts**
   - Upload generated SDK to workflow artifact storage
   - Allows atomic multi-version commit after all matrix jobs complete

#### Step 3: Post-Generation Processing (After All Matrix Jobs Complete)

1. **Download Artifacts**
   - Retrieve generated SDKs for all versions from artifact storage

2. **Track Generated Versions**
   - Record which directories were actually generated
   - Used by CHANGELOG automation to add entries only for generated versions

3. **Update CHANGELOG.md**
   - Call `ChangelogManager` with comma-separated list of generated versions
   - Command: `ruby .github/changelog_manager.rb v20111101,v20250224`
   - The class automatically:
     - Reads version numbers from each API's `package.json`
     - Sorts versions by priority (newer API versions first)
     - Extracts date range from existing entries
     - Inserts new entries at top of changelog with proper formatting
   - See [Changelog-Manager.md](Changelog-Manager.md) for full documentation
   - Example result:
     ```markdown
     # Changelog
     
     ## [3.0.1] - 2026-01-27 (v20250224 API)
     ### Changed
     - Updated v20250224 API specification...
     
     ## [2.0.1] - 2026-01-27 (v20111101 API)
     ### Changed
     - Updated v20111101 API specification...
     ```

4. **Copy Documentation to Version Directories**
   - After CHANGELOG update, copy root documentation to each version directory
   - Files: `LICENSE`, `CHANGELOG.md`, `MIGRATION.md` → `v20111101/` and `v20250224/`
   - Each npm package includes current changelog for users

#### Step 4: Commit All Changes to Master

- **Git Config**: Uses `devexperience` bot account
- **Commit Message**: `"Generated SDK versions: v20111101,v20250224"`
- **Files Committed**: Updated config files, generated SDK directories, updated CHANGELOG.md
- **Target Branch**: Directly commits to `master` (no PR created for automatic flow)
- **Atomic Operation**: All versions committed together in single commit

#### Step 5: Automatic Publish and Release (via on-push-master.yml)

**Architecture**: After `Process-and-Push` completes and pushes to master, the automatic `on-push-master.yml` workflow is triggered by GitHub's push event.

**Why This Architecture?**
- Separates concerns: `openapi-generate-and-push.yml` owns generation, `on-push-master.yml` owns publishing
- Enables consistent publish logic: All publishes (whether from automated generation or manual PR merge) go through the same workflow
- Prevents duplicate publishes: Manual generate.yml + PR merge only triggers publish once (via on-push-master.yml)

**Process** (handled by `on-push-master.yml`):
1. Check-skip-publish job detects if `[skip-publish]` flag is in commit message
2. For each version with path changes (v20111101/**, v20250224/**):
   - Publish job: Call `publish.yml` with version-specific directory
   - Release job: Call `release.yml` after publish completes
3. Path-based matrix execution ensures only modified versions are published

**Serialization Chain** (for race condition prevention):
- v20111101 publish runs first (depends on check-skip-publish)
- v20111101 release runs second (depends on publish) - waits for npm registry confirmation
- **gate-v20111101-complete** runs (uses `always()`, runs even if v20111101 jobs are skipped) ⭐ **Critical: Enables single-version publishing**
- v20250224 publish runs third (depends on gate job) ← **Serial ordering enforced**
- v20250224 release runs fourth (depends on v20250224 publish) - waits for npm registry confirmation

**Why This Order Matters**:
- Each version publishes to npm sequentially, never in parallel
- npm registry expects sequential API calls; parallel publishes can cause conflicts
- Gate job ensures this ordering works correctly whether 1 or 2 versions are modified
- Release jobs complete before the next version starts publishing

---

## Flow 2: Manual Multi-Version Generation (Workflow Dispatch)

### Trigger
Developer manually clicks "Run workflow" on `generate.yml` in GitHub Actions UI

### User Inputs

1. **api_version** (required): Which API version to generate
   - Options: `v20111101` or `v20250224`
   - Maps to correct config file automatically

2. **version_bump** (required): Version bump strategy
   - Options: `skip`, `minor`, or `patch` (no major option)
   - Major version locked to API version (semantic versioning)
   - `skip`: Generate without bumping version (test/review mode)

### Implementation

**Workflow**: `.github/workflows/generate.yml`

#### Step 1: Validate Configuration

- **Script**: `ruby .github/config_validator.rb <config_file> <api_version>`
- **Validation Checks**:
  1. **API Version Supported**: Verifies API version is in supported versions list (v20111101, v20250224)
  2. **Config File Exists**: Checks that config file exists at specified path
  3. **Config File Readable**: Validates YAML syntax and structure (must parse to Hash)
  4. **Semantic Versioning**: Enforces major version matches API version (v20111101→2.x.x, v20250224→3.x.x)
- **Fail Fast**: If any validation fails, workflow stops before version bumping or generation
- **Error Messages**: Clear, detailed messages indicate which check failed and how to fix it
- **See**: [Troubleshooting-Guide.md](Troubleshooting-Guide.md) for specific error messages and solutions

#### Step 2: Version Bumping (Conditional)

**Only runs if `version_bump` != `skip`**

- Script: `ruby .github/version.rb <minor|patch> openapi/config-v20111101.yml`
- Reads current version from config file
- Increments minor or patch based on input
- Writes updated version back to config file
- Output new version for next steps

#### Step 3: Clean Version Directory

- Script: `ruby .github/clean.rb v20111101`
- Deletes generated files from previous generation in that directory only
- Unrelated version directories untouched

#### Step 4: Generate SDK

- **Input Spec URL**: Master branch reference (not commit SHA)
  - `https://raw.githubusercontent.com/mxenabled/openapi/master/openapi/v20111101.yml`
  - Manual workflow doesn't have CDN cache concern since developer controls timing
- **Output Directory**: Version-specific (e.g., `v20111101/`)
- **Configuration**: Version-specific config file
- **Process**:
  1. Install OpenAPI Generator CLI
  2. Run TypeScript-Axios generator with selected config
  3. Copy documentation files to version directory

#### Step 5: Update CHANGELOG.md

- Call `ChangelogManager` with the selected API version
- Command: `ruby .github/changelog_manager.rb v20111101`
- The class reads version from `package.json`, formats entry, and inserts at top of changelog
- See [Changelog-Manager.md](Changelog-Manager.md) for full documentation

#### Step 6: Create Feature Branch

- **Branch Name**: `openapi-generator-v20111101-2.0.1`
- Format: `openapi-generator-<api_version>-<version>`
- Makes it easy to identify which API version each PR targets

#### Step 7: Create Pull Request

- **Command**: `gh pr create -f`
- **Destination**: Targets `master` branch
- **Status**: Awaits code review and approval before merging
- **Benefits**: Allows time to validate SDK quality and close/retry if needed

#### Step 8: Trigger Publishing (After PR Merge)

**Trigger**: When PR is merged to `master`, `on-push-master.yml` automatically activates

**Workflows Called**:
1. `publish.yml` (via workflow_call with version_directory input)
2. `release.yml` (via workflow_call with version_directory input)

**Result**: Same publishing and releasing as automatic flow

---

## Publishing via on-push-master.yml

All SDKs (whether from automatic generation or manual PR merge) are published through a single mechanism: the `on-push-master.yml` workflow that is triggered when changes are pushed to master.

This is the **only** path to publishing. Developers cannot publish directly; all publishes go through this workflow. In the future, master will be locked to prevent direct commits, ensuring only the automated `openapi-generate-and-push.yml` workflow can commit directly to master.

### Architecture Decision: Serial Publishing with Conditional Jobs

This section explains **why** we chose serial job chaining with conditionals instead of a more DRY (Don't Repeat Yourself) matrix-based approach.

#### Why Not Matrix Strategy?

**Matrix Approach** (More DRY, but unsafe):
```yaml
strategy:
  matrix:
    version:
      - { api: v20111101, dir: v20111101, prev_gate: check-skip-publish }
      - { api: v20250224, dir: v20250224, prev_gate: gate-v20111101 }

# Single publish job that runs for each version in parallel
publish:
  if: needs.check-skip-publish.outputs.skip_publish == 'false' && contains(github.event.head_commit.modified, matrix.version.dir)
  with:
    version_directory: ${{ matrix.version.dir }}
```

**Why we rejected this**:
- ❌ **Race conditions**: Both versions could start publishing simultaneously to npm registry
  - `npm publish` can be slow; timing varies per version
  - If both hit npm at nearly the same time, registry locks/conflicts could occur
  - npm doesn't guarantee atomic operations across parallel publishes
- ❌ **Loss of visibility**: When one version succeeds and another fails, the matrix obscures which one
  - GitHub Actions matrix UI shows one line, making it harder to debug individual version failures
  - Logs are nested, making failure diagnosis harder
- ❌ **Harder to understand**: New developers see one job with matrix logic; harder to reason about sequence
- ❌ **Less flexible**: Adding safety checks per version becomes complicated with matrix expansion

#### Why Serial Conditionals (Our Choice)

**Serial Approach** (Explicit, safe, maintainable):
```yaml
publish-v20111101:
  if: skip_publish == false && contains(modified, 'v20111101')
  
publish-v20250224:
  needs: [gate-v20111101-complete]  # Must wait
  if: skip_publish == false && contains(modified, 'v20250224')
```

**Advantages**:
- ✅ **Safe**: v20250224 cannot start publishing until v20111101 finishes
  - Gate job ensures serial ordering at job level, not just workflow level
  - npm registry sees sequential requests, no conflicts
  - Clear happens-before relationship in GitHub Actions UI
- ✅ **Visible**: Each version has individual jobs that are easy to identify
  - GitHub Actions shows separate rows for each version
  - Failures are obvious: "publish-v20250224 failed" vs "publish[v20250224] in matrix"
  - Each job can have version-specific comments and documentation
- ✅ **Debuggable**: Clear dependencies make it obvious what blocks what
  - When only v20250224 is modified, you see: `publish-v20111101 (skipped)` → `gate (runs)` → `publish-v20250224 (runs)`
  - Matrix approach would be harder to understand why certain jobs run/skip
- ✅ **Maintainable**: Adding a new version requires adding 3 explicit jobs (publish, release, gate)
  - More code, but each job is self-documenting
  - No complex matrix expansion logic to understand
  - Future developers can see the pattern easily: "oh, each version gets 3 jobs"
- ✅ **Future-proof**: When you lock master, this structure stays the same
  - Matrix would need version list hardcoded; serial jobs just live alongside each other

**Tradeoff we accepted**:
- We have more code (repetition): `publish-v20111101`, `publish-v20250224`, etc.
- BUT: The repetition is worth it for safety, clarity, and debuggability
- This is a conscious choice: **explicitness over DRY** for critical infrastructure



### Trigger
Push to `master` branch with changes in version-specific directories (`v20111101/**` or `v20250224/**`)

### Skip-Publish Safety Mechanism
Include `[skip-publish]` in commit message to prevent publish/release for this push.

**Use Case**: When making structural changes (e.g., directory migrations), commit with `[skip-publish]` flag to prevent accidental publishes.

### Implementation

**Workflow**: `.github/workflows/on-push-master.yml`

**Architectural Approach**: Serial job chaining with gate job pattern ensures single-version and multi-version publishing both work correctly while preventing npm race conditions.

#### Step 1: Check Skip-Publish Flag

**Job**: `check-skip-publish`

```yaml
- name: Check for skip-publish flag
  run: |
    if [[ "${{ github.event.head_commit.message }}" == *"[skip-publish]"* ]]; then
      echo "skip_publish=true" >> $GITHUB_OUTPUT
    else
      echo "skip_publish=false" >> $GITHUB_OUTPUT
    fi
```

- Parses HEAD commit message
- Sets output: `skip_publish` = true/false
- Used by subsequent jobs to determine execution

#### Step 2: Publish and Release v20111101 (First in Serial Chain)

**Jobs**: `publish-v20111101` and `release-v20111101`

**publish-v20111101 executes when**:
- No `[skip-publish]` flag
- Files in `v20111101/**` were changed

**release-v20111101 executes when**:
- No `[skip-publish]` flag
- Files in `v20111101/**` were changed
- **AND** `publish-v20111101` completes

**Process**:
1. Publish job calls `publish.yml` with `version_directory: v20111101`
2. Release job calls `release.yml` after publish completes

#### Step 3: Gate Job - Unblock v20250224 Publishing

**Job**: `gate-v20111101-complete`

```yaml
gate-v20111101-complete:
  runs-on: ubuntu-latest
  needs: [check-skip-publish, release-v20111101]
  if: always() && needs.check-skip-publish.outputs.skip_publish == 'false'
  steps:
    - name: Gate complete - ready for v20250224
      run: echo "v20111101 release workflow complete (or skipped)"
```

**Key Feature**: Uses `always()` condition - runs even when `release-v20111101` is skipped

**Why This Pattern Exists**:

The gate job solves a critical dependency problem in serial publishing:

1. **The Problem**: 
   - If v20250224 publish job depends on `release-v20111101`, it fails when v20111101 is skipped (not modified)
   - When only v20250224 is modified, we want it to publish, but it's blocked by skipped v20111101 job
   - This would cause the workflow to hang/fail when only one version is modified

2. **The Solution**:
   - Gate job uses `always()` so it runs whether v20111101 succeeds, fails, or is skipped
   - v20250224 jobs depend on the gate job (which always runs), not on v20111101 (which might be skipped)
   - This unblocks v20250224 while maintaining serial ordering when both versions are modified

3. **The Behavior**:
   - **Both versions modified**: publish v20111101 → release v20111101 → gate (runs) → publish v20250224 → release v20250224
   - **Only v20250224 modified**: (v20111101 jobs skipped) → gate (always runs, unblocks) → publish v20250224 → release v20250224
   - **Only v20111101 modified**: publish v20111101 → release v20111101 → gate (always runs) → publish v20250224 (skipped) → release v20250224 (skipped)

**Why Not Use Direct Dependencies?**
If v20250224 jobs depended directly on v20111101's release job, the workflow would fail whenever v20111101 was skipped (not modified). The gate job pattern enables:
- ✅ Correct behavior in single-version and multi-version scenarios
- ✅ Maintains serial ordering when both versions change
- ✅ Prevents race conditions at npm registry level
- ✅ Clear, explicit dependency chain in GitHub Actions UI

#### Step 4: Publish and Release v20250224 (Second in Serial Chain)

**Jobs**: `publish-v20250224` and `release-v20250224`

**publish-v20250224 executes when**:
- No `[skip-publish]` flag
- Files in `v20250224/**` were changed
- **AND** `gate-v20111101-complete` completes (ensures serial ordering)

**release-v20250224 executes when**:
- No `[skip-publish]` flag
- Files in `v20250224/**` were changed
- **AND** `publish-v20250224` completes

**Process**:
1. Publish job calls `publish.yml` with `version_directory: v20250224`
2. Release job calls `release.yml` after publish completes

**Serial Chain Benefit**: Even though both versions could publish in parallel, the gate job ensures v20250224 waits for v20111101 release, preventing npm registry race conditions when both versions are modified.

---

## Supporting Scripts

### version.rb - Multi-Version Support

**File**: `.github/version.rb`

**Purpose**: Increment version numbers in configuration files

**Usage**: `ruby .github/version.rb <minor|patch> [config_file]`

**Supported Options**:
- `minor`: Increment minor version (e.g., 2.0.0 → 2.1.0)
- `patch`: Increment patch version (e.g., 2.0.0 → 2.0.1)
- No `major` option (major version locked to API version)

**Important**: npmVersion as Source of Truth

The `npmVersion` field in the config file is the **authoritative source of truth** for the package version:

1. **Config File** (Source of Truth)
   - Contains persistent version number
   - Lives in Git, checked in with each update
   - Example: `openapi/config-v20111101.yml` contains `npmVersion: 2.0.0`

2. **version.rb Script** (Updates Source of Truth)
   - Reads current `npmVersion` from config file
   - Receives bump instruction: "patch" or "minor"
   - Calculates new version: 2.0.0 → 2.0.1 (patch) or 2.1.0 (minor)
   - **Writes updated npmVersion back to config file** (persists to Git)
   - Outputs new version to stdout (for workflow logging)

3. **package.mustache Template** (Uses Source of Truth)
   - Contains placeholder: `"version": "{{npmVersion}}"`
   - OpenAPI Generator replaces `{{npmVersion}}` with value from config file
   - Generates `package.json` with correct version number

4. **Result**
   - Generated `package.json` always has correct version
   - Version comes entirely from config file
   - No hardcoding in workflows or templates

### clean.rb - Version-Targeted Deletion

**File**: `.github/clean.rb`

**Purpose**: Remove generated SDK files before regeneration for a specific version

**Usage**: `ruby .github/clean.rb <version_dir>`

**Behavior**:
- Version-targeted deletion: deletes only specified version directory
- Protected files: `.git`, `.github`, `openapi`, other version directories, LICENSE, README, CHANGELOG
- Required parameter: must provide version directory name
- Error if parameter missing: raises clear error message

### changelog_manager.rb - Automatic CHANGELOG Updates

**File**: `.github/changelog_manager.rb`

**Purpose**: Maintain a shared CHANGELOG.md across multiple API versions with proper version ordering and date ranges

**Usage**: `ruby .github/changelog_manager.rb v20111101,v20250224`

**Key Features**:
- **Version Extraction**: Reads version numbers from each API's `package.json` 
- **Priority Sorting**: Automatically sorts entries by version (newest first), ensuring changelog follows standard conventions regardless of input order
- **Date Range Tracking**: Calculates date ranges showing what changed since the last update for each API version
- **Atomic Updates**: Inserts new entries at the top of the changelog with proper formatting
- **Validation**: Confirms versions are supported before processing

**When It's Called**:
- `generate.yml`: After generating a single API version (manual flow)
- `openapi-generate-and-push.yml`: After generating multiple API versions (automatic flow)

**Example Output**:
```markdown
## [3.2.0] - 2025-01-28 (v20250224 API)
Updated v20250224 API specification...

## [2.5.3] - 2025-01-28 (v20111101 API)
Updated v20111101 API specification...
```

**For Detailed Implementation**: See [Changelog-Manager.md](Changelog-Manager.md) for class methods, version ordering logic, and how to extend it for new API versions.

---

## Configuration Files

### openapi/config-v20111101.yml

```yaml
---
generatorName: typescript-axios
npmName: mx-platform-node
npmVersion: 2.0.0
apiVersion: v20111101
supportsES6: true
.openapi-generator-ignore: true
```

**Purpose**: Generates v20111101 API SDK as `mx-platform-node@2.x.x`

**Key Fields**:
- `npmVersion`: Source of truth for package version (updated by `version.rb`)
- `apiVersion`: Passed to `package.mustache` for description and metadata
- `npmName`: Same across all configs (single package name with multiple major versions)
- `generatorName`: Language/framework for code generation (TypeScript-Axios)
- `supportsES6`: Target JavaScript version for transpilation
- `.openapi-generator-ignore`: Prevents overwriting certain files

### openapi/config-v20250224.yml

```yaml
---
generatorName: typescript-axios
npmName: mx-platform-node
npmVersion: 3.0.0
apiVersion: v20250224
supportsES6: true
.openapi-generator-ignore: true
```

**Purpose**: Generates v20250224 API SDK as `mx-platform-node@3.x.x`

### openapi/templates/package.mustache

```json
{
  "name": "{{npmName}}",
  "version": "{{npmVersion}}",
  "description": "MX Platform Node.js SDK ({{apiVersion}} API)",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "apiVersion": "{{apiVersion}}",
  "files": [
    "dist/",
    "*.md"
  ],
  "scripts": {
    "build": "tsc --declaration",
    "test": "npm run build"
  },
  "dependencies": {
    "axios": "^1.6.2"
  }
}
```

**Key Features**:
- `"version"`: Uses `{{npmVersion}}` from config (source of truth)
- `"description"`: Includes `{{apiVersion}}` to identify which API version (visible in npm registry)
- `"apiVersion"`: Custom field for programmatic access to API version
- `"files"`: Explicitly controls what gets published (critical for multi-version from subdirectories)

**Consumer Discovery**:
- **In npm registry**: Description shows "MX Platform SDK (v20111101 API)" or "(v20250224 API)"
- **Programmatically**:
  ```javascript
  const pkg = require('mx-platform-node/package.json');
  console.log(pkg.apiVersion); // "v20111101" or "v20250224"
  ```

### openapi/templates/README.mustache

**Key Features**:
- Title includes `{{apiVersion}}`: `# MX Platform Node.js ({{apiVersion}} API)`
- SDK and API version clearly identified
- Version selection section explains available versions
- Links to correct API documentation per version

---

## Path-Based Triggers

### on-push-master.yml Path Configuration

```yaml
on:
  push:
    branches: [master]
    paths:
      - 'v20111101/**'     # Triggers publish/release for v20111101
      - 'v20250224/**'     # Triggers publish/release for v20250224
      # Does NOT trigger on:
      # - '.github/**'       (workflow changes)
      # - 'openapi/**'       (config changes alone)
      # - 'docs/**'          (documentation changes)
      # - 'README.md'        (root documentation)
```

**Benefits**:
- Enhancement PRs (docs only) don't trigger publish
- Workflow file changes don't trigger publish
- Only actual SDK code changes trigger publish/release
- Each version independently triggers when its directory changes
- Prevents false publishes from non-SDK changes

---

## Semantic Versioning Strategy

The repository uses **semantic versioning with major version = API version**:

| Version | API Version | Release Type | Notes |
|---------|------------|--------------|-------|
| 2.x.x | v20111101 | Stable | New minor/patch releases for spec updates |
| 3.x.x | v20250224 | Stable | New major version for new API version |
| 4.x.x | (future) | Future | When new API version available |

**Key Principle**: Major version number directly tied to API version number.
- Moving between major versions (2.x → 3.x) always means API change
- No confusion about which API version is in use
- Consumers can use `package.json` to determine API version

---

## Environment Variables & Secrets

### Required Secrets (`.github/secrets`)

| Secret | Used In | Purpose |
|--------|---------|---------|
| `NPM_AUTH_TOKEN` | publish.yml | Authenticate to npm registry for publishing |
| `GITHUB_TOKEN` | All workflows | GitHub API access (auto-provided by GitHub Actions) |
| `SLACK_WEBHOOK_URL` | All workflows | Send failure notifications to Slack |

### Environment Setup

- **Node**: v20.x (for npm operations)
- **Ruby**: 3.1 (for version.rb and clean.rb scripts)
- **OpenAPI Generator**: Latest version (installed via npm during workflow)
- **Git**: Configured with `devexperience` bot account for automatic commits

---

## Execution Timelines

### Automatic Flow Timeline

```
OpenAPI Repo: Commits change to v20111101.yml and v20250224.yml
        ↓
repository_dispatch: {"api_versions": "v20111101,v20250224"}
        ↓
openapi-generate-and-push.yml: Triggered
        ├─ Setup: Create matrix from api_versions
        ├─ Matrix[v20111101]: Clean, Bump, Generate (parallel)
        ├─ Matrix[v20250224]: Clean, Bump, Generate (parallel)
        ├─ Download artifacts
        ├─ Update CHANGELOG.md
        ├─ Commit to master
        ├─ Push to master (triggers on-push-master.yml)
        ↓
on-push-master.yml: Triggered (push event)
        ├─ check-skip-publish: Verify no [skip-publish] flag
        ├─ publish-v20111101: npm publish (path filter matched)
        ├─ release-v20111101: Create tag v2.0.1 (after publish)
        ├─ publish-v20250224: npm publish (serialized, after v20111101 release)
        ├─ release-v20250224: Create tag v3.0.1 (after publish)
        ↓
Result: Both versions published and released sequentially, CHANGELOG updated
```

### Manual Flow Timeline

```
Developer: Runs generate.yml (api_version, version_bump)
        ↓
generate.yml: Validate, Bump (if needed), Clean, Generate
        ├─ Update CHANGELOG.md (via changelog_manager.rb)
        ├─ Create feature branch
        ├─ Create Pull Request
        ↓
Code Review: Developer reviews and merges PR to master
        ↓
on-push-master.yml: Triggered (push event)
        ├─ check-skip-publish: false (no skip flag in merge commit)
        ├─ publish[matching_version]: npm publish (path filter matches)
        ├─ release[matching_version]: Create tag (after publish)
        ↓
Result: Selected version published and released
```

---

## Reference

For quick guides and troubleshooting, see:
- [Multi-Version-SDK-Flow.md](Multi-Version-SDK-Flow.md) - Architecture overview and diagrams
- [Adding-a-New-API-Version.md](Adding-a-New-API-Version.md) - Step-by-step guide for new versions
- [Troubleshooting-Guide.md](Troubleshooting-Guide.md) - Common issues and solutions
