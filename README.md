# TCS Shared GitHub Actions Workflows

[![CI Validate](https://img.shields.io/github/actions/workflow/status/ntatschner/tcs-shared-workflows/ci-validate.yml?branch=main&label=CI%20Validate)](https://github.com/ntatschner/tcs-shared-workflows/actions/workflows/ci-validate.yml)
[![Docs Generation](https://img.shields.io/github/actions/workflow/status/ntatschner/tcs-shared-workflows/generate-docs.yml?branch=main&label=Docs)](https://github.com/ntatschner/tcs-shared-workflows/actions/workflows/generate-docs.yml)
[![Publish to PSGallery](https://img.shields.io/github/actions/workflow/status/ntatschner/tcs-shared-workflows/publish-to-psgallery.yml?branch=main&label=Publish)](https://github.com/ntatschner/tcs-shared-workflows/actions/workflows/publish-to-psgallery.yml)
[![Publish Docs Website](https://img.shields.io/github/actions/workflow/status/ntatschner/tcs-shared-workflows/publish-docs-website.yml?branch=main&label=Docs%20Site)](https://github.com/ntatschner/tcs-shared-workflows/actions/workflows/publish-docs-website.yml)

This repository contains reusable GitHub Actions workflows for PowerShell module development, including validation, documentation generation, and publishing to PowerShell Gallery and documentation websites.

**Adding a new module repo?** See [NEW_MODULE.md](NEW_MODULE.md) for the contract (required/optional inputs), checklist, and template workflow files so you can add a new module without changing CI/CD.

## Available Workflows

### 1. PowerShell Module Validation (`ci-validate.yml`)

Validates a PowerShell module using inputs supplied by the caller workflow:
- Manifest validation with required field checks
- PSScriptAnalyzer linting with configurable severities
- Import verification and exported function inspection
- Optional smoke-test script execution

**Usage:**
```yaml
jobs:
  validate:
    uses: ntatschner/tcs-shared-workflows/.github/workflows/ci-validate.yml@main
    with:
      module-name: 'MyModule'
      module-path: './modules/MyModule'
      install-modules: |
        tcs.core
        Microsoft.Graph.Authentication
      smoke-test-script-path: '.github/scripts/smoke-tests.ps1'
```

### 2. PowerShell Documentation Generation (`generate-docs.yml`)

Generates PlatyPS markdown help and external help files for a module:
- Installs optional dependencies before import
- Supports custom pre-import scripts for stubs or setup
- Writes markdown help and about files to a configurable docs folder
- Generates localized external help and optionally commits changes

**Usage:**
```yaml
jobs:
  docs:
    uses: ntatschner/tcs-shared-workflows/.github/workflows/generate-docs.yml@main
    with:
      module-name: 'MyModule'
      module-path: './modules/MyModule'
      docs-path: './docs'
      required-modules: |
        PlatyPS
        tcs.core
      pre-import-script-path: '.github/scripts/setup-doc-stubs.ps1'
      commit-docs: true
    secrets:
      repo-token: ${{ secrets.DOCS_PUSH_TOKEN }} # optional, defaults to GITHUB_TOKEN
```

### 3. PowerShell Gallery Publishing (`publish-to-psgallery.yml`)

Publishes a module artifact to the PowerShell Gallery:
- Optional pre-publish validation (linting + import test)
- Checks if the requested version already exists unless force-publish is enabled
- Attempts both Publish-PSResource and Publish-Module for compatibility
- Can automatically create a GitHub release after publishing

**Usage:**
```yaml
jobs:
  publish:
    uses: ntatschner/tcs-shared-workflows/.github/workflows/publish-to-psgallery.yml@main
    with:
      module-name: 'MyModule'
      module-path: './modules/MyModule'
      force-publish: false
      create-release: true
      run-validation: true
    secrets:
      psgallery-api-key: ${{ secrets.PSGALLERY_API_KEY }}
```

### 4. Documentation Website Publishing (`publish-docs-website.yml`)

Publishes generated documentation to an external site (API method implemented; git/ftp paths deliberately fail fast until implemented):
- Validates doc path and file count
- Packages docs with metadata
- Posts to a configurable API endpoint with optional dry-run

**When to use:** Call this workflow from a module repo when you have an external documentation site with an API that accepts doc packages (e.g. after `generate-docs` has run). No TCS module repo uses it yet; add a job that calls this workflow when you have a docs site API and the required secrets (`WEBSITE_API_KEY`, optional `WEBSITE_AUTH_TOKEN`).

**Usage:**
```yaml
jobs:
  publish-docs:
    uses: ntatschner/tcs-shared-workflows/.github/workflows/publish-docs-website.yml@main
    with:
      docs_path: './docs'
      website_api_endpoint: 'https://docs.example.com/api/publish'
      publish_method: 'api' # 'git' and 'ftp' currently exit as not implemented
      module_name: 'MyModule'
      docs_version: '1.0.0'
      dry_run: false
    secrets:
      WEBSITE_API_KEY: ${{ secrets.DOCS_API_KEY }}
```

## Versioning shared workflows

Callers currently use `@main` (e.g. `.../ci-validate.yml@main`). To avoid unexpected breakage when shared workflows change, you can pin to a versioned tag:

1. In **tcs-shared-workflows**, create a tag (e.g. `v1`) on the commit you want to ship:  
   `git tag v1 && git push origin v1`
2. In each **module repo**, change workflow references from `@main` to `@v1` (or the tag you use).

When you intentionally roll out a new workflow version, update the tag (e.g. move `v1` to a new commit, or introduce `v2`) and update module repos to the new tag. Document tag meanings in this repo (e.g. in release notes or this README) so consumers know when to bump.

## Required Secrets

### For PowerShell Gallery Publishing
- `PSGALLERY_API_KEY`: Your PowerShell Gallery API key

### Optional
- `repo-token`: Personal access token with `contents:write` if you need to push from documentation or publish jobs using a non-default token

## Workflow Inputs and Outputs

Each workflow provides detailed inputs and outputs. See the individual workflow files for complete documentation of available parameters.

### Common Patterns

- **Explicit inputs**: Workflows require the caller to provide module paths, names, and optional scripts for complete flexibility
- **Caching**: PowerShell modules are cached to keep runs fast while remaining configurable
- **Robust logging**: Each step emits contextual PowerShell output to simplify troubleshooting
- **Extensibility**: Optional inputs (smoke tests, pre-import scripts, commit control) keep workflows generic yet adaptable
- **Module layout**: Prefer `modules/<name>` so local dependency probing aligns with the built-in search heuristics

## RequiredModules resolution and strict failure behavior

The workflows use a shared composite action (`.github/actions/resolve-required-modules`) to satisfy `RequiredModules` declared in a module's manifest (`.psd1`) before importing the target module. This keeps resolution logic in one place (install from PSGallery, then try local paths) and is used by ci-validate, generate-docs, and publish-to-psgallery. This helps avoid confusing import failures when a module lists nested dependencies (for example, `tcs.utils` requiring `tcs.core`).

Behavior summary:
- The workflow resolves the manifest path and reads the `RequiredModules` entry.
- For each required module it will:
  - First try to install it from PSGallery using `Install-Module`.
  - If PSGallery install fails, it checks several common local paths relative to the manifest/repo (for example `modules/<name>`, `<name>\<name>.psd1`) and attempts to `Import-Module` from there.
- If any required module remains unresolved after those attempts the workflow will write an error and fail (throw). The failing message will look like:

  `Required module(s) could not be resolved: tcs.core, Other.Module`

How to avoid a failure
- Publish the dependency on PSGallery so the workflow can `Install-Module` it.
- Provide the dependency in the same repository checkout (for example add `modules/tcs.core`), so the workflow picks it up from local paths.
- Use the workflow inputs `required-modules` / `install-modules` (where available) to explicitly request installation of modules prior to import. Example input uses are shown in the workflow usage sections above.

If you'd prefer the workflows to be tolerant (warn but continue) instead of failing, you can either remove the `RequiredModules` entry from the manifest or modify the workflow to change the final `throw` into a `Write-Warning`. If you'd like, I can add an input flag to make strict failure configurable — tell me and I will implement that.

## Contributing

1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Test with your own PowerShell modules
5. Submit a pull request

## License

MIT License - see LICENSE file for details
