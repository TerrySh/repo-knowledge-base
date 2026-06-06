---
name: repo-knowledge-base
description: Generate and maintain a repository knowledge base for existing codebases or new projects. Use when Codex needs to inspect a repo, start a project from scratch, identify technologies and frameworks, enumerate or plan modules, create knowledge-base files, write per-module specs, infer or define coding standards, keep knowledge-base files synchronized after code changes, or ensure a repo has a knowledge base before implementing, refactoring, debugging, or reviewing code.
---

# Repo Knowledge Base

## Overview

Use this skill to create and maintain `knowledge-base/` for a repository so future agents can understand the project before changing it. The knowledge base is part of the repo's working context, not a replacement for reading source code.

## Knowledge Base Gate

Before implementing, refactoring, debugging, or reviewing code in a repository:

1. Check whether `knowledge-base/` exists at the repository root.
2. If it does not exist, stop and tell the user the repo has no knowledge base yet.
3. Ask whether to create the initial knowledge base before continuing.
4. If the user agrees, run Generate Mode first.
5. After the initial knowledge base is created, continue with the original task.
6. If the user declines, continue with normal repo inspection and do not create knowledge-base files.

Use this response when `knowledge-base/` is missing:

```text
This repo does not have `knowledge-base/` yet. I recommend generating it first so I can understand the repo structure, coding standards, modules, commands, and relevant specs before changing code. Should I create the initial knowledge base and then continue with your requested change?
```

Do not silently create a knowledge base unless the user's request explicitly asks for it.

## Initialize Mode

Use Initialize Mode when starting a new project from scratch or when the repository has little or no source code yet.

1. Ask for the intended product/domain, users, technology stack, runtime, package manager, deployment target, and initial modules if they are not clear from the user's request.
2. Create the project scaffold first when the user asked for implementation.
3. Create `knowledge-base/` immediately after the scaffold exists.
4. Use `Planned`, `Assumed`, and `Implemented` labels where needed.
5. Do not describe planned behavior as already implemented.
6. As features are implemented, move knowledge from planned state to current implementation facts.

Initialize Mode adds these files:

```text
knowledge-base/
|-- product-brief.md
`-- roadmap.md
```

- `product-brief.md`: target users, problem statement, product goals, core concepts, assumptions, and open questions.
- `roadmap.md`: planned phases, initial features, future modules, and implementation status.

For new projects, distinguish planned design from implemented facts. This is mandatory.

## Generate Mode

Use Generate Mode when the repo does not have `knowledge-base/`, when the user asks to create one, or when the user explicitly asks to regenerate it.

1. Inspect the repository root and existing documentation.
2. Run a scaffold script from the repo root to create the initial structure.
   - On Windows, prefer `scripts/scaffold_knowledge_base.ps1`.
   - Use `scripts/scaffold_knowledge_base.py` when Python is available.
   - If neither script can run, manually create the same structure and templates.
3. Read code, tests, manifests, routes, configs, schemas, and docs before filling specs.
4. Update generated draft files with evidence from the repo.
5. Mark uncertainty in `Open Questions`; do not present guesses as facts.

Default output structure:

```text
knowledge-base/
|-- README.md
|-- product-brief.md
|-- roadmap.md
|-- repo-map.md
|-- tech-stack.md
|-- commands.md
|-- coding-standards.md
|-- workflows.md
|-- architecture.md
|-- testing.md
|-- modules.md
|-- modules/
|   `-- <module-name>/
|       |-- spec.md
|       |-- design.md
|       |-- implementation-notes.md
|       `-- decisions.md
`-- changes/
```

Create optional global docs such as `data-model.md`, `api-surface.md`, `dependencies.md`, `deployment.md`, and `troubleshooting.md` only when the repo evidence supports them or the user asks for them.

## Maintenance Mode

Use Maintenance Mode when implementing, refactoring, debugging, or reviewing code in a repo that already has `knowledge-base/`.

Before code changes:

1. Read `knowledge-base/README.md` if present.
2. Read `knowledge-base/commands.md`.
3. Read `knowledge-base/coding-standards.md`.
4. Read `knowledge-base/repo-map.md`.
5. Read affected module specs under `knowledge-base/modules/`.
6. Read deeper module files only when needed.

After code changes:

1. Identify changed modules.
2. Update affected `spec.md` files if behavior, APIs, data model, dependencies, side effects, tests, or business rules changed.
3. Update `coding-standards.md` only if a repo-wide convention changed.
4. Update `tech-stack.md` only if dependencies, frameworks, build tools, or runtime changed.
5. Update `commands.md` only if commands or local workflow changed.
6. Add or update `decisions.md` only for meaningful architectural or business decisions.
7. Create a file in `knowledge-base/changes/` for meaningful implementation work.

Do not update the knowledge base for formatting-only edits, line-number churn, trivial copy changes, or local cleanup with no behavioral meaning.

## Document Responsibilities

- `README.md`: Agent reading order and update rules.
- `product-brief.md`: Product/domain brief for new projects or business-heavy repos.
- `roadmap.md`: Planned features, phases, and implementation status for new or evolving projects.
- `repo-map.md`: Directory map and ownership of major paths.
- `tech-stack.md`: Languages, frameworks, runtime, package managers, build tools, and detected manifests.
- `commands.md`: Install, run, build, lint, typecheck, test, migration, codegen, and deployment commands.
- `coding-standards.md`: Actual conventions inferred from this repo, not generic advice.
- `workflows.md`: Common implementation workflows such as adding APIs, pages, jobs, migrations, or config.
- `architecture.md`: Global architecture, boundaries, request flow, state management, persistence, auth, queues, cache, and error handling.
- `testing.md`: Test types, locations, fixtures, mocking style, commands, and expectations.
- `modules.md`: Index of detected modules with short summaries.
- `modules/<module>/spec.md`: Current facts about the module's purpose, business logic, public interfaces, data model, side effects, dependencies, tests, and risks.
- `modules/<module>/design.md`: Design intent, boundaries, tradeoffs, and evolution path.
- `modules/<module>/implementation-notes.md`: Detailed call flow, state machines, transactions, caching, concurrency, and edge cases.
- `modules/<module>/decisions.md`: Important architecture or business decisions.
- `changes/<date>-<slug>.md`: Meaningful implementation records with plan, files changed, behavior changes, tests, knowledge-base updates, and follow-ups.

Keep `spec.md` focused on the current truth. Put historical plans and implementation records in `changes/`.

## Module Detection

Prefer `rg` and `rg --files` for repo scanning. Look for modules in:

- frontend pages, routes, components, stores, hooks
- backend routes, controllers, services, models, repositories
- packages, apps, libs, crates, gems, plugins, workers
- domain folders under `src/`, `app/`, `services/`, `modules/`, `packages/`
- generated code only when it is a meaningful integration surface

Do not treat dependency folders, build output, caches, or vendored code as modules.

## Coding Standards

Infer coding standards from source files, linters, formatters, tests, configs, and existing architecture. Include:

- naming conventions
- file and folder organization
- import/export style
- module boundary rules
- error handling
- data access patterns
- testing patterns
- formatting, linting, and type-checking commands
- agent rules for making changes safely

Do not write generic coding advice unless the repo evidence supports it.

## Change Records

Create a change record under `knowledge-base/changes/` when the work includes:

- new feature
- cross-module change
- complex bug fix
- API change
- data model change
- architecture change
- new dependency
- significant test strategy change

Do not create change records for trivial edits, formatting-only changes, copy updates, or local-only cleanup.

Use `references/change-record-template.md` as the starting format.

## Script Usage

From a repository root on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File C:\path\to\repo-knowledge-base\scripts\scaffold_knowledge_base.ps1
```

From a repository root when Python is available:

```bash
python /path/to/repo-knowledge-base/scripts/scaffold_knowledge_base.py
```

Useful options:

```powershell
powershell -ExecutionPolicy Bypass -File C:\path\to\repo-knowledge-base\scripts\scaffold_knowledge_base.ps1 -Force
powershell -ExecutionPolicy Bypass -File C:\path\to\repo-knowledge-base\scripts\scaffold_knowledge_base.ps1 -Initialize
powershell -ExecutionPolicy Bypass -File C:\path\to\repo-knowledge-base\scripts\scaffold_knowledge_base.ps1 -ModuleDepth 2
```

```bash
python /path/to/repo-knowledge-base/scripts/scaffold_knowledge_base.py --force
python /path/to/repo-knowledge-base/scripts/scaffold_knowledge_base.py --initialize
python /path/to/repo-knowledge-base/scripts/scaffold_knowledge_base.py --module-depth 2
```

The scripts create missing files only by default. Use `--force` or `-Force` only when the user explicitly wants to overwrite generated knowledge-base drafts.

If Python is unavailable on Windows, do not stop. Use the PowerShell script. If script execution is blocked by local policy, ask the user whether to allow `-ExecutionPolicy Bypass` for this one command, or manually create the files using the same structure.

## References

- `references/spec-template.md`: module spec template.
- `references/design-template.md`: module design template.
- `references/implementation-notes-template.md`: detailed implementation notes template.
- `references/decisions-template.md`: module decisions template.
- `references/change-record-template.md`: implementation change record template.
- `references/product-brief-template.md`: new-project product brief template.
- `references/roadmap-template.md`: new-project roadmap template.
