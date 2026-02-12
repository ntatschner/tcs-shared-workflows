# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **reusable GitHub Actions workflow repository** for PowerShell module CI/CD. Consumer module repos invoke these workflows via `workflow_call` (e.g., `uses: ntatschner/tcs-shared-workflows/.github/workflows/ci-validate.yml@main`). There is no application code, build system, or test suite in this repo itself — all logic lives in YAML workflow files and PowerShell scripts embedded within them.

## Repository Structure

```
.github/
  workflows/
    ci-validate.yml           # PSScriptAnalyzer linting, manifest validation, import testing
    generate-docs.yml         # PlatyPS markdown + external help generation, auto-commit
    publish-to-psgallery.yml  # Publish to PSGallery with validation, dual-method fallback
    publish-docs-website.yml  # API-based docs site publishing (git/ftp not yet implemented)
    create-version-tag.yml    # Compare manifest version to latest tag, create if newer
  actions/
    resolve-required-modules/ # Composite action: install from PSGallery, then try local paths
      action.yml
      Resolve-RequiredModules.ps1
```

Key docs: [README.md](README.md) (usage guide), [NEW_MODULE.md](NEW_MODULE.md) (onboarding contract and templates).

## Development Workflow

There are no local build/test/lint commands. Changes are tested by having a consumer module repo invoke the workflows. To test changes:

1. Push to a branch in this repo
2. In a consumer repo, temporarily point workflow references to your branch (`@your-branch` instead of `@main`)
3. Trigger the consumer workflow (push, PR, or `workflow_dispatch`)

Versioning: Consumers can pin to tags (e.g., `@v1`) for stability. Move tags with `git tag -f v1 && git push --force origin v1`.

## Architecture Patterns

**All workflows are `workflow_call` only** — they have no direct triggers. Every workflow requires `module-name` and `module-path` inputs from the caller. Manifest path defaults to `{module-path}/{module-name}.psd1`.

**Dependency resolution** is centralized in the `resolve-required-modules` composite action, shared by ci-validate, generate-docs, and publish-to-psgallery. Resolution order: PSGallery install → local path probing (`modules/<name>`, `<name>/<name>.psd1`, etc.) → strict failure (throw).

**Expected consumer module layout:**
```
modules/<module-name>/
  <module-name>.psd1    # Manifest (version source of truth)
  <module-name>.psm1    # Module file
  Public/               # Exported functions
  Private/              # Internal functions
  <locale>/             # External help (e.g., en-GB)
```

**Publish workflow** uses a multi-job pattern: validate → publish → notify. Publishing tries `Publish-PSResource` first, then falls back to `Publish-Module`.

**generate-docs.yml** is the most complex workflow (~470 lines). It contains extensive inline PowerShell for YAML normalization of PlatyPS output — regex-based fixing of block formatting, key renaming, line-wrapping, and two full normalization passes (before and after `Update-MarkdownHelpModule`).

## Conventions

- **Commit messages**: Conventional commits (`feat:`, `fix:`, `chore:`, `docs:`)
- **PowerShell**: All scripts use `$ErrorActionPreference = 'Stop'` and explicit try-catch
- **Platform**: Workflows run on `windows-latest` except `publish-docs-website.yml` (Ubuntu)
- **Git in workflows**: Auto CRLF disabled, hard reset before rebase to prevent checkout-induced changes
- **Doc commits**: Default message includes `[skip ci]` to avoid re-triggering CI
- **Version tags**: Prefixed with `v` (e.g., `v1.0.3`), derived from manifest `ModuleVersion`
- **Secrets**: `PSGALLERY_API_KEY` for publishing; `repo-token` optional (defaults to `GITHUB_TOKEN`)
