# Adding a New PowerShell Module Repository

This guide describes the **contract** between module repos and the shared workflows, and a **checklist** so you can add a new module repo without changing CI/CD.

## Contract: Required and Optional Inputs

Every module repo that uses these workflows must provide:

| Input | Workflow(s) | Required | Description |
|-------|-------------|----------|-------------|
| `module-name` | All | **Yes** | Name of the PowerShell module (e.g. `tcs.utils`). |
| `module-path` | All | **Yes** | Relative path to the module directory containing the manifest (e.g. `modules/tcs.utils`). |

Optional inputs (use when your module needs them):

| Input | Workflow(s) | Description |
|-------|-------------|-------------|
| `install-modules` | ci-validate | Newline-separated list of modules to install before validation (e.g. `tcs.core`). |
| `smoke-test-script-path` | ci-validate | Path to a PowerShell script for extra smoke tests (e.g. `.github/scripts/module-smoke-tests.ps1`). |
| `required-modules` | generate-docs | Newline-separated list of modules to install before generating docs. |
| `pre-import-script-path` | generate-docs | Path to a script that runs before importing the module (e.g. stubs for doc generation). |
| `docs-path` | generate-docs | Where to write markdown docs (default: `./docs`). |
| `commit-docs` | generate-docs | Whether to commit generated docs (default: `true`). |
| `commit-message` | generate-docs | Commit message when docs are updated. |
| `locale` | generate-docs | Locale for external help (e.g. `en-GB`). |
| `ref` | publish-to-psgallery | Ref to checkout (e.g. release tag). Leave empty for tag push / default ref. |

## Repository Layout

Use this layout so path filters and defaults line up:

- Module code: `modules/<module-name>/`
- Manifest: `modules/<module-name>/<module-name>.psd1`
- Optional scripts: `.github/scripts/`
- Docs output: `./docs`

## New Module Checklist

1. **Create the repo** with branch `main` (and optionally `dev`).

2. **Add the three workflow files** under `.github/workflows/`:
   - `ci-validate.yml`
   - `generate-docs.yml`
   - `publish-to-psgallery.yml`

3. **Set required inputs** in each workflow:
   - Replace `MODULE_NAME` with your module name (e.g. `tcs.mymodule`).
   - Replace `MODULE_PATH` with your module path (e.g. `modules/tcs.mymodule`).

4. **Add optional inputs** only if needed:
   - If the module depends on other modules (e.g. `tcs.core`), set `install-modules` in CI and/or `required-modules` in generate-docs.
   - If you need doc stubs or pre-import setup, add `pre-import-script-path` and the script under `.github/scripts/`.
   - If you want extra validation, add `smoke-test-script-path` and the script.

5. **Configure repository secret** `PSGALLERY_API_KEY` for publishing.

6. **Keep triggers and path filters as in the template** so all modules behave the same:
   - CI: `pull_request` and `push` on `main`, paths `modules/**` and `.github/workflows/**`.
   - generate-docs: `push` and `pull_request` on `main` and `dev`, paths `modules/**/*.ps1`, `*.psm1`, `*.psd1`, plus `workflow_dispatch`.
   - publish: `push` tags `v*` and `workflow_dispatch` with optional force-publish.

## Template: CI Validate (ci-validate.yml)

```yaml
name: CI - Validate Module

on:
  pull_request:
    branches: [ main ]
    paths:
      - 'modules/**'
      - '.github/workflows/**'
  push:
    branches: [ main ]
    paths:
      - 'modules/**'
      - '.github/workflows/**'

jobs:
  validate:
    name: Validate Module
    uses: ntatschner/tcs-shared-workflows/.github/workflows/ci-validate.yml@main
    with:
      module-name: 'MODULE_NAME'      # e.g. tcs.mymodule
      module-path: 'MODULE_PATH'      # e.g. modules/tcs.mymodule
      # install-modules: |            # optional, e.g. tcs.core
      # smoke-test-script-path: '.github/scripts/module-smoke-tests.ps1'  # optional
```

## Template: Generate Docs (generate-docs.yml)

```yaml
name: Generate PowerShell Documentation

on:
  push:
    branches: [ main, dev ]
    paths:
      - 'modules/**/*.ps1'
      - 'modules/**/*.psm1'
      - 'modules/**/*.psd1'
  pull_request:
    branches: [ main, dev ]
    paths:
      - 'modules/**/*.ps1'
      - 'modules/**/*.psm1'
      - 'modules/**/*.psd1'
  workflow_dispatch:

jobs:
  docs:
    permissions:
      contents: write
      pull-requests: write
    uses: ntatschner/tcs-shared-workflows/.github/workflows/generate-docs.yml@main
    with:
      module-name: 'MODULE_NAME'
      module-path: 'MODULE_PATH'
      docs-path: './docs'
      commit-docs: true
      commit-message: 'docs: auto-generated PowerShell help via PlatyPS [skip ci]'
      locale: 'en-GB'
      # required-modules: |           # optional
      # pre-import-script-path: '.github/scripts/setup-doc-stubs.ps1'  # optional
```

## Template: Publish to PSGallery (publish-to-psgallery.yml)

```yaml
name: Publish to PowerShell Gallery

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      force_publish:
        description: 'Force publish even if version exists'
        required: false
        default: false
        type: boolean

jobs:
  publish:
    uses: ntatschner/tcs-shared-workflows/.github/workflows/publish-to-psgallery.yml@main
    with:
      module-name: 'MODULE_NAME'
      module-path: 'MODULE_PATH'
      force-publish: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.force_publish == 'true' }}
      create-release: ${{ startsWith(github.ref, 'refs/tags/v') }}
      run-validation: true
    secrets:
      psgallery-api-key: ${{ secrets.PSGALLERY_API_KEY }}
```

## Publishing a New Version

1. Update `ModuleVersion` in the module manifest (e.g. `modules/<name>/<name>.psd1`).
2. Commit and push to `main`.
3. Create and push a tag: `git tag v1.0.0 && git push origin v1.0.0`.
4. The publish workflow runs, validates, publishes to PowerShell Gallery, and creates a GitHub release.

Alternatively, run the "Publish to PowerShell Gallery" workflow manually from the Actions tab (optionally with "Force publish" if the version already exists).
