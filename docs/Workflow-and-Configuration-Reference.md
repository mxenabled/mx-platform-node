# Workflow and Configuration Reference

**Document Purpose**: Detailed technical reference for the multi-version SDK generation, publishing, and release workflows. Covers implementation details, configuration files, and system architecture.

**Last Updated**: January 27, 2026  
**Audience**: Developers who need to understand or modify the implementation

---

## Flow 1: Automatic Multi-Version Generation (Repository Dispatch)

### Trigger
OpenAPI specifications change in the upstream `openapi` repository → Repository sends `repository_dispatch` event with optional `api_versions` payload → `generate_publish_release.yml` workflow is triggered

### Backward Compatibility Model
- **No Payload (v20111101 only)**: If openapi repo sends `repository_dispatch` without `api_versions` field, defaults to generating v20111101 only
- **Single Version Payload** (`api_versions: "v20111101"`): Generates only the specified version
- **Multi-Version Payload** (`api_versions: "v20111101,v20250224"`): Generates both versions in parallel

This allows phased migration: current behavior works as-is, and when the openapi repo is ready for multi-version, no code changes are needed in mx-platform-node.

### Implementation

**Workflow**: `.github/workflows/generate_publish_release.yml`

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
     Updated v20250224 API specification...
     
     ## [2.0.1] - 2026-01-27 (v20111101 API)
     Updated v20111101 API specification...
     ```

4. **Copy Documentation to Version Directories**
   - After CHANGELOG update, copy root documentation to each version directory
   - Files: `LICENSE`, `CHANGELOG.md`, `MIGRATION.md` → `v20111101/` and `v20250224/`
   - Each npm package includes current changelog for users

#### Step 4: Commit All Changes to Master

- **Git Config**: Uses `devexperience` bot account
- **Commit Message**: `"Generated Node.js SDKs [v20111101=2.0.1,v20250224=3.0.1]"`
- **Files Committed**: Updated config files, generated SDK directories, updated CHANGELOG.md
- **Target Branch**: Directly commits to `master` (no PR created for automatic flow)
- **Atomic Operation**: All versions committed together in single commit

#### Step 5: Publish to npm (Parallel Matrix Execution)

**Architecture**: Uses `workflow_call` to invoke `publish.yml` as reusable workflow

**Why workflow_call?** Repository dispatch events don't support input parameters. `workflow_call` allows passing `version_directory` to specify which version directory contains the SDK to publish.

**Process**:
1. Call `publish.yml` with version-specific directory
2. Navigate to version directory (e.g., `v20111101/`)
3. Install dependencies: `npm install`
4. Publish to npm: `npm publish` (no tag for production)
5. Use `NPM_AUTH_TOKEN` secret for authentication

**Result**:
- `mx-platform-node@2.0.1` published to npm (v20111101 API)
- `mx-platform-node@3.0.1` published to npm (v20250224 API)
- Both major versions coexist on npm registry under same package name

#### Step 6: Create GitHub Releases (Parallel Matrix Execution)

**Same architecture as publish**: Uses `workflow_call` to invoke `release.yml`

**Process**:
1. Read version from version-specific `package.json`
2. Create GitHub release with version-specific tag (e.g., `v2.0.1`, `v3.0.1`)
3. Release body includes API version and links to API documentation

**Result**:
- GitHub release `v2.0.1` created (v20111101 API)
- GitHub release `v3.0.1` created (v20250224 API)
- Both versions have separate release history

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

#### Step 1: Validate Inputs

- **Config File Exists**: Verify selected API version config file exists
- **Semantic Versioning Check**: Verify major version matches API version
- **Fail Fast**: If validation fails, workflow stops before any generation

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

**Trigger**: When PR is merged to `master`, `on-push-master.yml` automatically activates (see Flow 3)

**Workflows Called**:
1. `publish.yml` (via workflow_call with version_directory input)
2. `release.yml` (via workflow_call with version_directory input)

**Result**: Same publishing and releasing as automatic flow

---

## Flow 3: Auto-Publish Trigger with Path-Based Matrix Execution (on-push-master.yml)

### Trigger
Push to `master` branch with changes in version-specific directories (`v20111101/**` or `v20250224/**`)

### Skip-Publish Safety Mechanism
Include `[skip-publish]` in commit message to prevent publish/release for this push.

**Use Case**: When making structural changes (e.g., directory migrations), commit with `[skip-publish]` flag to prevent accidental publishes.

### Implementation

**Workflow**: `.github/workflows/on-push-master.yml`

**Architectural Approach**: Matrix strategy with conditional execution per iteration eliminates code duplication while maintaining clear, independent version management.

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

#### Step 2: Matrix-Based Publish Jobs

**Matrix Definition**:
```yaml
strategy:
  matrix:
    version:
      - api_version: v20111101
        npm_version: 2
      - api_version: v20250224
        npm_version: 3
```

**For Each Version**:

**Job Executes When**:
- No upstream failures (`!cancelled()`)
- No `[skip-publish]` flag in commit message
- Files in this version's directory were changed

**Process**:
1. Call `publish.yml` with version-specific directory
2. Navigate to version directory
3. Install dependencies and publish to npm
4. Each version publishes independently with its own version number

**Result**: Each version publishes independently, no race conditions, parallel execution when both versions changed

#### Step 3: Matrix-Based Release Jobs

**Same Matrix Strategy as Publish**

**For Each Version**:

**Job Executes When**:
- Same conditions as publish (skip-publish flag, path match)
- **Plus**: Only after its corresponding publish job succeeds

This ensures each version's release depends only on its own publish job, preventing race conditions.

**Process**:
1. Call `release.yml` with version-specific directory
2. Read version from that directory's `package.json`
3. Create GitHub release with version-specific tag

**Result**: Each version released independently, ordered after its corresponding publish job

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
generate_publish_release.yml: Triggered
        ├─ Matrix[v20111101]: Clean, Bump, Generate (parallel)
        ├─ Matrix[v20250224]: Clean, Bump, Generate (parallel)
        ├─ Download artifacts
        ├─ Update CHANGELOG.md
        ├─ Commit to master
        ├─ publish[v20111101]: npm publish (parallel)
        ├─ publish[v20250224]: npm publish (parallel)
        ├─ release[v20111101]: Create tag v2.0.1 (parallel)
        ├─ release[v20250224]: Create tag v3.0.1 (parallel)
        ↓
Result: Both versions published and released, CHANGELOG updated
```

### Manual Flow Timeline

```
Developer: Runs generate.yml (api_version, version_bump)
        ↓
generate.yml: Validate, Bump (if needed), Clean, Generate
        ├─ Update CHANGELOG.md
        ├─ Create feature branch
        ├─ Create Pull Request
        ↓
Code Review: Developer reviews and merges PR
        ↓
on-push-master.yml: Triggered
        ├─ check-skip-publish: false
        ├─ publish[matching_version]: npm publish
        ├─ release[matching_version]: Create tag
        ↓
Result: Selected version published and released
```

---

## Reference

For quick guides and troubleshooting, see:
- [Multi-Version-SDK-Flow.md](Multi-Version-SDK-Flow.md) - Architecture overview and diagrams
- [Adding-a-New-API-Version.md](Adding-a-New-API-Version.md) - Step-by-step guide for new versions
- [Troubleshooting-Guide.md](Troubleshooting-Guide.md) - Common issues and solutions
