# Repo Knowledge Base Skill

This repository contains a Codex skill for generating and maintaining a `knowledge-base/` folder inside software projects.

The skill helps agents understand a repo before changing it by documenting the project structure, technology stack, commands, coding standards, modules, business logic, design notes, implementation details, decisions, and meaningful change records.

## Contents

```text
repo-knowledge-base/
|-- SKILL.md
|-- agents/
|   `-- openai.yaml
|-- references/
|   |-- change-record-template.md
|   |-- decisions-template.md
|   |-- design-template.md
|   |-- implementation-notes-template.md
|   |-- product-brief-template.md
|   |-- roadmap-template.md
|   `-- spec-template.md
`-- scripts/
    |-- scaffold_knowledge_base.ps1
    `-- scaffold_knowledge_base.py
```

## Install

Copy the skill folder into your Codex skills directory:

```powershell
Copy-Item -Recurse -Force `
  .\repo-knowledge-base `
  "$env:USERPROFILE\.codex\skills\repo-knowledge-base"
```

Open a new Codex thread after installing so the skill metadata can be discovered.

## Usage

For an existing repo:

```text
Use repo-knowledge-base to generate a knowledge-base for the current repo. Scan the tech stack, modules, coding standards, and fill the main module specs.
```

For a new project:

```text
Use repo-knowledge-base initialize mode while creating this project. Create product-brief.md, roadmap.md, architecture docs, coding standards, and module plans.
```

For ongoing development:

```text
Implement the requested feature and keep knowledge-base files synchronized with any meaningful behavior, API, data model, dependency, test, or architecture changes.
```

## Scaffold Scripts

Windows without Python:

```powershell
powershell -ExecutionPolicy Bypass -File C:\path\to\repo-knowledge-base\scripts\scaffold_knowledge_base.ps1
```

New project mode on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File C:\path\to\repo-knowledge-base\scripts\scaffold_knowledge_base.ps1 -Initialize
```

Python available:

```bash
python /path/to/repo-knowledge-base/scripts/scaffold_knowledge_base.py
python /path/to/repo-knowledge-base/scripts/scaffold_knowledge_base.py --initialize
```

Both scripts create missing files only by default. Use `-Force` or `--force` only when you intentionally want to overwrite generated drafts.

## Git

This repository tracks the skill folder and this README from the parent directory so the skill can be packaged, copied, or published as a single repo.
