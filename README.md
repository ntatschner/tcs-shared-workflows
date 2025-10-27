# TCS Shared GitHub Actions Workflows

This repository contains reusable GitHub Actions workflows for PowerShell module development, including validation, documentation generation, and publishing to PowerShell Gallery and documentation websites.

## Available Workflows

### 1. PowerShell Module Validation (`powershell-validate.yml`)

Validates PowerShell modules with comprehensive checks including:
- Module manifest validation
- PSScriptAnalyzer linting
- Module import testing
- Help documentation verification
- Custom function testing

**Usage:**
```yaml
jobs:
  validate:
    uses: ntatschner/tcs-shared-workflows/.github/workflows/powershell-validate.yml@main
    with:
      module_name: 'MyModule'
      module_path: './src/MyModule'
      run_function_tests: true
      test_functions: |
        [
          {
            "name": "Get-Something",
            "command": "Get-Something -Name 'test'",
            "expected": "test-result"
          }
        ]
```

### 2. PowerShell Documentation Generation (`powershell-docs.yml`)

Generates markdown documentation using PlatyPS and creates external help files:
- Generates markdown help files for all exported functions
- Creates module about pages
- Generates external help XML files
- Commits documentation back to repository

**Usage:**
```yaml
jobs:
  generate-docs:
    uses: ntatschner/tcs-shared-workflows/.github/workflows/powershell-docs.yml@main
    with:
      module_name: 'MyModule'
      module_path: './src/MyModule'
      docs_path: './docs'
      required_modules: '["Microsoft.Graph.Authentication", "tcs.core"]'
      stub_functions: |
        [
          {
            "name": "Get-ModuleConfig",
            "definition": "param($CommandPath) return @{ModuleName='MyModule'}"
          }
        ]
```

### 3. PowerShell Gallery Publishing (`powershell-publish.yml`)

Publishes PowerShell modules to the PowerShell Gallery:
- Optional pre-publish validation
- Version existence checking
- Multiple publishing methods (PSResourceGet and legacy PowerShellGet)
- GitHub release creation
- Comprehensive error handling

**Usage:**
```yaml
jobs:
  publish:
    uses: ntatschner/tcs-shared-workflows/.github/workflows/powershell-publish.yml@main
    with:
      module_name: 'MyModule'
      module_path: './src/MyModule'
      force_publish: false
      create_github_release: true
      run_validation: true
    secrets:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
```

### 4. Documentation Website Publishing (`publish-docs-website.yml`)

Publishes documentation to websites via API:
- Supports multiple documentation formats (markdown, HTML, JSON)
- API-based publishing with authentication
- Dry run capability
- File inventory and metadata generation
- Extensible for different publishing methods

**Usage:**
```yaml
jobs:
  publish-docs:
    uses: ntatschner/tcs-shared-workflows/.github/workflows/publish-docs-website.yml@main
    with:
      docs_path: './docs'
      website_api_endpoint: 'https://mysite.com/api/docs/upload'
      docs_format: 'markdown'
      module_name: 'MyModule'
      docs_version: '1.0.0'
      publish_method: 'api'
    secrets:
      WEBSITE_API_KEY: ${{ secrets.WEBSITE_API_KEY }}
      WEBSITE_AUTH_TOKEN: ${{ secrets.WEBSITE_AUTH_TOKEN }}
```

## Complete Pipeline Example

See `complete-pipeline-example.yml` for a full example that combines all workflows:

```yaml
name: Complete PowerShell Module Pipeline

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main ]

jobs:
  validate:
    uses: ntatschner/tcs-shared-workflows/.github/workflows/powershell-validate.yml@main
    with:
      module_name: 'MyModule'
      module_path: './src/MyModule'

  generate-docs:
    needs: validate
    if: github.ref == 'refs/heads/main'
    uses: ntatschner/tcs-shared-workflows/.github/workflows/powershell-docs.yml@main
    with:
      module_name: 'MyModule'
      module_path: './src/MyModule'

  publish-psgallery:
    needs: [validate, generate-docs]
    if: startsWith(github.ref, 'refs/tags/v')
    uses: ntatschner/tcs-shared-workflows/.github/workflows/powershell-publish.yml@main
    with:
      module_name: 'MyModule'
      module_path: './src/MyModule'
    secrets:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}

  publish-docs-website:
    needs: [validate, generate-docs]
    if: needs.generate-docs.outputs.docs_generated == 'true'
    uses: ntatschner/tcs-shared-workflows/.github/workflows/publish-docs-website.yml@main
    with:
      docs_path: './docs'
      website_api_endpoint: 'https://mysite.com/api/docs'
      module_name: 'MyModule'
    secrets:
      WEBSITE_API_KEY: ${{ secrets.WEBSITE_API_KEY }}
```

## Required Secrets

### For PowerShell Gallery Publishing
- `PSGALLERY_API_KEY`: Your PowerShell Gallery API key

### For Documentation Website Publishing
- `WEBSITE_API_KEY`: API key for your documentation website
- `WEBSITE_AUTH_TOKEN`: Optional additional authentication token

## Workflow Inputs and Outputs

Each workflow provides detailed inputs and outputs. See the individual workflow files for complete documentation of available parameters.

### Common Patterns

- **Conditional execution**: Workflows include smart conditionals to run only when appropriate
- **Error handling**: Comprehensive error handling with detailed logging
- **Caching**: PowerShell module caching to speed up workflow execution
- **Cross-platform**: Most workflows support both Windows and Linux runners
- **Flexible configuration**: Extensive input parameters for customization

## Contributing

1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Test with your own PowerShell modules
5. Submit a pull request

## License

MIT License - see LICENSE file for details
shared workflows to perform doc creation and publishing of powershell modules
