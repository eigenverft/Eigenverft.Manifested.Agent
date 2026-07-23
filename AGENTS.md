# AGENTS.md

## Required confirmation
- Confirm that you have read `AGENTS.md`.
- The confirmation must be ultra-short.
- On the first read for a task or session, review all applicable sections below before proceeding.

## Checked steps summary
- After the confirmation, provide a status summary of all applicable `AGENTS.md` checks and actions for the current task. (only description should be short, the list should be exesive and should cover sections and subtasks in this section)
- Do not omit any applicable section that was reviewed, executed, skipped, blocked, or deferred.
- Use short checklist items only.
- Use these status markers:
  - `[x]` completed or checked
  - `[-]` skipped because not applicable
  - `[!]` blocked, deferred, or requires user input
- If an item is skipped, blocked, or deferred, include a very short reason.
- On the first read for a task or session, this summary must cover all applicable sections triggered by `AGENTS.md`, not just a selective subset.
- Keep it brief, factual, and execution-focused.
- If a later section requires a prompt-only response, the required confirmation and this checklist summary are still allowed and do not count as extra commentary.

Example:
- [x] Read `AGENTS.md`
- [x] Reviewed task list requirement
- [x] Checked `.gitignore`
- [-] Skipped GitHub CLI checks (`gh` not available)
- [!] Deferred structure migration; prompt generation only

## Change summary
- If following `AGENTS.md` caused any changes, include an ultra-short factual summary together with the `AGENTS.md` update.
- Reference `AGENTS.md` as the reason for the change.
- Omit this section if nothing was changed.

## Execution behavior
- For any non-trivial request, first decompose the work into an executable task list before making code changes.
- If the work naturally splits into distinct phases, chains, or concern areas, organize the plan into task groups instead of one flat list.
- Create task groups when separate workstreams improve clarity, such as setup, refactoring, implementation, validation, documentation, or follow-up fixes.
- Keep task lists concrete and action-oriented.
- Keep exactly one task in progress at a time unless parallel work is clearly safe and beneficial.
- Update the task list whenever scope changes, new dependencies are discovered, or a task is completed, blocked, or no longer relevant.
- Preserve execution momentum: task tracking should support implementation, not delay it.
- For trivial, localized work, skip task decomposition and execute directly.
- The initial `AGENTS.md` confirmation and checklist summary are always allowed, even when another section restricts the rest of the output format.
- Before finishing, reconcile the task structure so each task or subtask is marked as completed, blocked, cancelled, or intentionally deferred.

## Other AGENTS.md Files

### .agents/AGENTS-PROJECT.md
- If `.agents/AGENTS-PROJECT.md` does not exist, create it.
- If it already exists, review and update it when repository-specific guidance is missing, outdated, or too vague.
- `.agents/AGENTS-PROJECT.md` should contain only repository-specific instructions that help an agent work correctly in this codebase.
- It should complement `AGENTS.md`, not repeat general execution rules already defined there.
- Include concrete project facts such as:
  - project purpose and main components
  - repository structure and important directories
  - targeted runtime and toolchain versions
  - IDE / development environment version and required extensions or setup
  - build, test, lint, typecheck, and local run commands
  - project-specific coding conventions and architectural constraints
  - generated files, protected areas, or files that should not be edited manually
  - validation steps required before finishing changes
  - environment, dependency, or deployment notes relevant to development
- Keep the file concise, actionable, and specific to the repository.
- Prefer facts and instructions over broad descriptions.
- The `.agents/AGENTS-PROJECT.md` file needs to include at least a minimal list of top-level directories and their purpose.
- If the repository contains `.github/workflows/*.yml` or `.github/workflows/*.yaml` files, `.agents/AGENTS-PROJECT.md` should summarize the relevant workflows, including their trigger conditions and the main actions they run, so an agent is aware of what may happen on push, pull request, merge, or manual dispatch.
- Keep `.agents/AGENTS-PROJECT.md` updated with the OS and OS version of the user's current active development environment so the agent always knows which system the user is working on, using scripting or shell commands to determine that information when possible.

## Git specific
- If Git is not available or the workspace is not a Git repository, skip this section.
- Ensure the repository has a `.gitignore` file.
- If `.gitignore` does not exist, create it.
- Check whether the following ignore patterns are present in `.gitignore`:
  - `*[Ss][Ee][Cc][Rr][Ee][Tt]*`
  - `*[Kk][Ee][Yy]*`
  - `AGENTS.md`
  - `.agents/**/*`
  - `.gemini/**/*`
- If these files is both tracked and ignored, remove it from Git tracking (`git rm --cached`) while keeping the file in the working tree.
- Do not untrack files that are not ignored.
- If any of these patterns are missing, add them.
- Do not add duplicate entries if an equivalent pattern already exists.
- Preserve existing `.gitignore` contents and append missing rules in a minimal way.

## GitHub CLI specific (with Git)
- If Git or `gh` is not available, skip this section.
- Check that this is a Git repository.
- Identify the effective remote and resolve its GitHub owner/repo.
- Check that `gh` is installed and authenticated.
- Verify that `gh` can access the same repository.
- Compare with `gh repo list` if helpful.
- Report any mismatch clearly.
- Do not change remotes or authentication.

## GitHub CLI actions
- If Git or `gh` is not available, skip this section.
- Proceed with `gh` actions only if the Git remote and the current `gh` context resolve to the same GitHub owner/repository.
- Require confirmed `gh` authentication and confirmed access to that repository.
- If either check fails, skip the rest of this section.
- Do not modify remotes or authentication automatically.
- Read open issues to get current project context and known problem areas.
- Update with gh the issue labels if not present add priority:critical, priority:high, priority:medium, priority:low, feature, improvement, refactor, performance, design
- Treat issues as hints, not as verified facts.
- Do not investigate or fix issues unless the current task explicitly requires it.
- Use issue context only to inform decisions and avoid redundant or conflicting actions.
- Check the repository description and topic tags.
- If they are missing, incomplete, outdated, or clearly inaccurate, update them.
- If the existing description and topic tags are already present and sufficiently accurate, leave them unchanged.


## GitHub repositories
- Read `.git/config` in read-only mode to determine whether the repository is hosted on GitHub.
- If it is not a GitHub repository, skip this section.
- There are currently no additional GitHub-repository-specific instructions here, so skip this section.

## Year references in informational text
- Update outdated informational year references, including copyright or licensing notices, to the current year where appropriate.
- Do not change ranges like `2025-2026`.
- Do not change code, structured, or historical year references.
- If unsure, leave it unchanged.

## Source code directory structure
- All source code must be stored under `/src`.
- The layout must always support multiple workspaces, even if only one exists.
- Each repository must define one or more workspaces.
- Workspace-specific files must be stored in `/src/wrk/<workspace-name>/`.
- All projects belonging to any workspace must be stored in `/src/prj`.
- At least one project must exist with the exact same name as the workspace. This is the main project.
- If the technology uses a dedicated workspace or solution file, the main workspace file must be placed directly in `/src`.
- If the technology does not use a dedicated workspace or solution file, the absence of such a file in `/src` is not a deviation.
- If deviations from this target structure exist, do not perform the analysis or migration in this step.
- Instead, generate only a generic prompt for the user that instructs the agent to analyze the current structure and convert it to the required target structure.
- This output must contain only:
  - the required ultra-short `AGENTS.md` confirmation,
  - the required very short `AGENTS.md` checklist summary,
  - and the proposed user prompt.
- It must not include the actual deviation analysis, migration plan, implementation details, or any other non-required commentary.

Example:
For a workspace named `MyApp`:
- Main workspace file if supported: `/src/MyApp.sln`
- Workspace-specific files: `/src/wrk/MyApp/`
- Main project: `/src/prj/MyApp/`
- Other projects: `/src/prj/MyApp.Lib/`, `/src/prj/MyApp.Tests/`

### Suggested generic user prompt:
- If deviations from this target structure exist, do not perform the analysis or migration in this step.
- Instead, output exactly one generic user prompt that instructs the agent to analyze the current structure and migrate the repository to the required target structure.
- That generated prompt must explicitly restrict the migration to structure and reference changes only, require preservation of runtime behavior and existing file-internal code shape, allow only minimal path or location-dependent reference edits, and forbid logic refactors, control-flow rewrites, abstraction changes, comment rewrites, formatting rewrites, and unrelated fixes.
- That generated prompt must also require loader, bootstrap, manifest, import, include, and dot-source files to keep their existing statement structure and ordering wherever possible, changing only referenced paths unless a different change is strictly unavoidable for the structural migration.
- This output must contain only:
  - the required ultra-short `AGENTS.md` confirmation,
  - the required very short `AGENTS.md` checklist summary,
  - and that single proposed user prompt.
- Do not include the actual deviation analysis, migration plan, implementation details, or other non-required commentary.

## PowerShell specific source directoy structure
- Apply this section only if the repository or workspace is a dedicated PowerShell project. Otherwise, skip this section.
- PowerShell does not require a dedicated workspace or solution file.
- Therefore, for dedicated PowerShell projects, no workspace file is required in `/src`.
- The absence of a dedicated workspace file in `/src` is not a deviation.
- The main PowerShell module project must be stored at:
  - `/src/prj/<main-module-name>/`
- For the main project, `<main-module-name>` must exactly match the workspace name.

### Main module files
The following files must exist in:

`/src/prj/<main-module-name>/`

- `<main-module-name>.psm1`
- `<main-module-name>.psd1`
- `<main-module-name>.ps1`

### Source layout
The module source code should be organized as:

- `/src/prj/<main-module-name>/Public/`
- `/src/prj/<main-module-name>/Private/Common/`
- `/src/prj/<main-module-name>/Private/Logic/`
- `/src/prj/<main-module-name>/Private/Infra/`

### Tests
- If tests exist, they should be stored as a separate project under:
  - `/src/prj/<main-module-name>.Test/`

### Output artifacts
- Build or publish output is not source code.
- Output directories must not be placed under `/src/prj`.
- Use a repository-level output directory instead, for example:
  - `/out/<main-module-name>/`

### Suggested generic user prompt:
- If deviations from this target structure exist, do not perform the analysis or migration in this step.
- Instead, output exactly one generic user prompt that instructs the agent to analyze the current structure and migrate the repository to the required target structure.
- That generated prompt must explicitly restrict the migration to structure and reference changes only, require preservation of runtime behavior and existing file-internal code shape, allow only minimal path or location-dependent reference edits, and forbid logic refactors, control-flow rewrites, abstraction changes, comment rewrites, formatting rewrites, and unrelated fixes.
- That generated prompt must also require loader, bootstrap, manifest, import, include, and dot-source files to keep their existing statement structure and ordering wherever possible, changing only referenced paths unless a different change is strictly unavoidable for the structural migration.
- This output must contain only:
  - the required ultra-short `AGENTS.md` confirmation,
  - the required very short `AGENTS.md` checklist summary,
  - and that single proposed user prompt.
- Do not include the actual deviation analysis, migration plan, implementation details, or other non-required commentary.

## Powershell source files, pick a random source file review and documentation requirement
- Select one random file from the source folder that contains source code.
- Verify that the file is documented appropriately for its language and role.
- You are allowed to fix up this file functions comment-based help if there completly missing.
- You are allowed to update one functions comment-based help if it seems outdated or false.
- If the file defines functions, commands, classes, or other callable units, ensure they include suitable inline or structured documentation.
- For PowerShell functions, use comment-based help in this general form:
```
function <FunctionName> {
<#
.SYNOPSIS
Brief summary of the function.

.DESCRIPTION
Longer description of the purpose and behavior.

.PARAMETER <ParameterName>
Description of the parameter.

.PARAMETER <ParameterName>
Description of the parameter.

.EXAMPLE
Example usage.

.EXAMPLE
Another example usage.

.NOTES
Optional additional notes.
#>
    [CmdletBinding(PositionalBinding = $false)]
    param(
        ...
    )
}
```