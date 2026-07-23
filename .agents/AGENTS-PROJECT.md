# AGENTS-PROJECT.md

## Project Purpose
- Windows-focused PowerShell module for repeatable Windows Sandbox and fresh-machine bootstrap.
- Main capabilities: bootstrap PowerShell package setup and initialize managed runtimes for PowerShell 7, Git, GitHub CLI, VS Code, Node.js, OpenCode, Gemini, Qwen, Codex, and VC++ prerequisites.

## Active Development Environment
- OS: Microsoft Windows 11 Pro 10.0.26200
- Shell: PowerShell
- Editor setup in repo: `.vscode/`

## Top-Level Layout
- `.agents/`: local agent guidance and skills; keep local-only.
- `.github/`: GitHub Actions workflows and CI/CD scripts.
- `.vscode/`: workspace editor settings.
- `iwr/`: raw-download bootstrap scripts intended for `iwr | iex` entrypoints.
- `resources/`: static assets such as screenshots and logos.
- `src/`: workspace and project source roots.

## Current Source Layout
- Workspace-specific files live in `src/wrk/Eigenverft.Manifested.Sandbox/`.
- Main module project lives in `src/prj/Eigenverft.Manifested.Sandbox/`.
- Repo-local test/import utilities live in `src/prj/Eigenverft.Manifested.Sandbox.Test/`.
- The PowerShell module keeps `Eigenverft.Manifested.Sandbox.psm1` and `.psd1` at the project root and organizes scripts under `Public/`, `Private/Common/`, `Private/Logic/`, and `Private/Infra/`.

## Runtime And Toolchain Facts
- Module manifest: `src/prj/Eigenverft.Manifested.Sandbox/Eigenverft.Manifested.Sandbox.psd1`
- Minimum PowerShell: 5.1
- Compatible editions: Desktop, Core
- Keep changes compatible with both Windows PowerShell 5.1 and PowerShell 7+ unless the task explicitly changes support policy.

## Project Conventions
- Keep the current `Public/` and `Private/*` layout unless the task is specifically another structure refactor.
- Keep exported functions declared explicitly in the manifest; do not switch to wildcard exports.
- Preserve the structure and comments in `src/prj/Eigenverft.Manifested.Sandbox/Eigenverft.Manifested.Sandbox.psd1`; the file explicitly warns against reshaping it.
- Treat `iwr/*.ps1` as bootstrap entrypoints that should remain simple, Windows-friendly, and raw-download safe.

## Validation Commands
- Manifest check: `Test-ModuleManifest .\src\prj\Eigenverft.Manifested.Sandbox\Eigenverft.Manifested.Sandbox.psd1`
- Import check: `Import-Module .\src\prj\Eigenverft.Manifested.Sandbox\Eigenverft.Manifested.Sandbox.psd1 -Force`
- Pester sketch: `Invoke-Pester .\src\prj\Eigenverft.Manifested.Sandbox.Test\Eigenverft.Manifested.Sandbox.Module.Tests.ps1`
- Module script analyzer: `.\src\prj\Eigenverft.Manifested.Sandbox.Test\Invoke-ModuleScriptAnalyzer.ps1` (analyzes all `.ps1` files in `src\prj\Eigenverft.Manifested.Sandbox`, uses `.vscode\PSScriptAnalyzerSettings.psd1` when present, falls back to plain severity defaults when it is missing, and writes JSON to stdout)
- Export check: `Get-Command -Module Eigenverft.Manifested.Sandbox`
- CI-like script: `.github\workflows\cicd.ps1` (publishing-oriented; use carefully because it expects secrets and external connectivity)

## Workflows
- `.github/workflows/cicd.yml`: triggers on push to `src/**` for main/master and branch families such as feature/hotfix/release/develop/bugfix, plus `repository_dispatch` type `builddispatch` and manual dispatch; runs on Windows, checks out the repo, prints environment info, shows `pwsh --version`, and executes `.github/workflows/cicd.ps1`.
- `.github/workflows/deploy_github_pages.yml`: triggers on pushes affecting `docs/**` on main/master branches and sub-branches, plus `repository_dispatch` type `builddispatch` and manual dispatch; uploads `./docs` and deploys GitHub Pages on Ubuntu.

## Sensitive Or Local-Only Files
- `AGENTS.md` and `.agents/**/*` are local-only guidance and should stay untracked.
- `.github/workflows/cicd.secrets.json` is a local secrets file pattern and must not be committed with real credentials.

## Finish Checklist
- Run at least the manifest and import checks after module changes.
- Avoid committing local-only agent files or secrets-bearing files.
- If a change touches workflow behavior or bootstrap flows, review the matching README section for drift.
