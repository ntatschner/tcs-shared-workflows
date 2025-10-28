# TCS Shared GitHub Actions Workflows

This repository contains reusable GitHub Actions workflows for PowerShell module development, including validation, documentation generation, and publishing to PowerShell Gallery and documentation websites.

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
      module-path: './src/MyModule'
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
      module-path: './src/MyModule'
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
      module-path: './src/MyModule'
      force-publish: false
      create-release: true
      run-validation: true
    secrets:
      psgallery-api-key: ${{ secrets.PSGALLERY_API_KEY }}
```

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

## Contributing

1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Test with your own PowerShell modules
5. Submit a pull request

## License

MIT License - see LICENSE file for details
shared workflows to perform doc creation and publishing of powershell modules
