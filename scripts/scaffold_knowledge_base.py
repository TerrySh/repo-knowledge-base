#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path


IGNORE_DIRS = {
    ".git",
    ".hg",
    ".svn",
    ".idea",
    ".vscode",
    ".cache",
    ".next",
    ".nuxt",
    ".turbo",
    ".venv",
    "venv",
    "env",
    "node_modules",
    "dist",
    "build",
    "out",
    "coverage",
    "target",
    "vendor",
    "__pycache__",
}

MANIFESTS = [
    "package.json",
    "pnpm-lock.yaml",
    "yarn.lock",
    "package-lock.json",
    "bun.lockb",
    "pyproject.toml",
    "requirements.txt",
    "Pipfile",
    "poetry.lock",
    "go.mod",
    "Cargo.toml",
    "pom.xml",
    "build.gradle",
    "settings.gradle",
    "Gemfile",
    "composer.json",
    "deno.json",
    "deno.jsonc",
    "mix.exs",
    "pubspec.yaml",
]

CONFIGS = [
    "tsconfig.json",
    "vite.config.ts",
    "vite.config.js",
    "next.config.js",
    "next.config.mjs",
    "nuxt.config.ts",
    "tailwind.config.js",
    "tailwind.config.ts",
    "eslint.config.js",
    ".eslintrc",
    ".eslintrc.json",
    "prettier.config.js",
    ".prettierrc",
    "jest.config.js",
    "vitest.config.ts",
    "playwright.config.ts",
    "pytest.ini",
    "ruff.toml",
    "mypy.ini",
    "Makefile",
    "Dockerfile",
    "docker-compose.yml",
]

MODULE_ROOTS = [
    "src",
    "app",
    "apps",
    "packages",
    "libs",
    "modules",
    "services",
    "server",
    "client",
    "frontend",
    "backend",
    "api",
    "cmd",
    "internal",
    "pkg",
]

SOURCE_EXTENSIONS = {
    ".js",
    ".jsx",
    ".ts",
    ".tsx",
    ".mjs",
    ".cjs",
    ".py",
    ".go",
    ".rs",
    ".java",
    ".kt",
    ".cs",
    ".rb",
    ".php",
    ".ex",
    ".exs",
    ".swift",
    ".dart",
}


def rel(path, root):
    return path.relative_to(root).as_posix()


def write_file(path, content, force=False):
    if path.exists() and not force:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return True


def safe_name(module_path):
    safe = re.sub(r"[^A-Za-z0-9._-]+", "__", module_path.strip("/\\"))
    return safe.strip("._-") or "root"


def existing_files(root, names):
    return [name for name in names if (root / name).exists()]


def load_package_json(root):
    path = root / "package.json"
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def detect_frameworks(root):
    frameworks = set()
    package_json = load_package_json(root)
    if package_json:
        deps = {}
        for key in ["dependencies", "devDependencies", "peerDependencies"]:
            value = package_json.get(key)
            if isinstance(value, dict):
                deps.update(value)
        candidates = [
            "react",
            "next",
            "vue",
            "nuxt",
            "svelte",
            "@sveltejs/kit",
            "angular",
            "@angular/core",
            "express",
            "fastify",
            "koa",
            "@nestjs/core",
            "vite",
            "typescript",
            "tailwindcss",
            "jest",
            "vitest",
            "playwright",
            "cypress",
            "prisma",
            "drizzle-orm",
        ]
        for candidate in candidates:
            if candidate in deps:
                frameworks.add(candidate)

    if (root / "pyproject.toml").exists() or (root / "requirements.txt").exists():
        frameworks.add("python")
    if (root / "go.mod").exists():
        frameworks.add("go")
    if (root / "Cargo.toml").exists():
        frameworks.add("rust")
    if (root / "pom.xml").exists() or (root / "build.gradle").exists():
        frameworks.add("jvm")

    return sorted(frameworks)


def package_scripts(root):
    package_json = load_package_json(root)
    if not package_json:
        return {}
    scripts = package_json.get("scripts")
    return scripts if isinstance(scripts, dict) else {}


def dir_has_source(path):
    try:
        for child in path.iterdir():
            if child.is_file() and child.suffix in SOURCE_EXTENSIONS:
                return True
    except OSError:
        return False
    return False


def detect_modules(root, module_depth):
    modules = set()

    for root_name in MODULE_ROOTS:
        base = root / root_name
        if not base.exists() or not base.is_dir():
            continue

        children = [
            child
            for child in base.iterdir()
            if child.is_dir() and child.name not in IGNORE_DIRS and not child.name.startswith(".")
        ]

        if not children:
            modules.add(rel(base, root))
            continue

        for child in children:
            if module_depth <= 1:
                modules.add(rel(child, root))
                continue

            grandchildren = [
                grandchild
                for grandchild in child.iterdir()
                if grandchild.is_dir()
                and grandchild.name not in IGNORE_DIRS
                and not grandchild.name.startswith(".")
            ]
            if grandchildren:
                for grandchild in grandchildren:
                    if dir_has_source(grandchild):
                        modules.add(rel(grandchild, root))
                modules.add(rel(child, root))
            else:
                modules.add(rel(child, root))

    if not modules:
        source_dirs = []
        for child in root.iterdir():
            if child.is_dir() and child.name not in IGNORE_DIRS and not child.name.startswith("."):
                if dir_has_source(child):
                    source_dirs.append(rel(child, root))
        modules.update(source_dirs)

    return sorted(modules)


def repo_map_content(root, manifests, configs, modules):
    top_dirs = [
        rel(path, root)
        for path in sorted(root.iterdir(), key=lambda p: p.name.lower())
        if path.is_dir() and path.name not in IGNORE_DIRS and not path.name.startswith(".")
    ]
    return (
        "# Repo Map\n\n"
        "## Top-Level Directories\n\n"
        + ("\n".join(f"- `{item}`: TODO" for item in top_dirs) if top_dirs else "- TODO\n")
        + "\n\n## Important Manifests\n\n"
        + ("\n".join(f"- `{item}`" for item in manifests) if manifests else "- TODO\n")
        + "\n\n## Important Configs\n\n"
        + ("\n".join(f"- `{item}`" for item in configs) if configs else "- TODO\n")
        + "\n\n## Detected Module Roots\n\n"
        + ("\n".join(f"- `{item}`" for item in modules) if modules else "- TODO\n")
        + "\n"
    )


def readme_content():
    return """# Knowledge Base

## Agent Reading Order

For any code task:
1. Read `commands.md`.
2. Read `coding-standards.md`.
3. Read `repo-map.md`.
4. Read affected module specs under `modules/`.

For architecture changes:
1. Read `architecture.md`.
2. Read affected module `design.md` and `decisions.md`.

For API changes:
1. Read `api-surface.md` if present.
2. Read affected module specs.
3. Update tests and change records.

## Update Rule

After meaningful code changes, update affected knowledge-base files before finishing.

Do not update knowledge-base files for formatting-only changes, trivial copy changes, or edits with no behavioral meaning.
"""


def tech_stack_content(manifests, configs, frameworks):
    return (
        "# Tech Stack\n\n"
        "## Detected Manifests\n\n"
        + ("\n".join(f"- `{item}`" for item in manifests) if manifests else "- TODO\n")
        + "\n\n## Detected Configs\n\n"
        + ("\n".join(f"- `{item}`" for item in configs) if configs else "- TODO\n")
        + "\n\n## Detected Languages And Frameworks\n\n"
        + ("\n".join(f"- `{item}`" for item in frameworks) if frameworks else "- TODO: inspect source imports and configs.\n")
        + "\n\n## Runtime And Package Managers\n\nTODO\n"
    )


def commands_content(scripts):
    if scripts:
        npm_commands = "\n".join(f"- `npm run {name}`: `{cmd}`" for name, cmd in sorted(scripts.items()))
    else:
        npm_commands = "- TODO: inspect package manager, Makefile, task runner, or project docs."
    return (
        "# Commands\n\n"
        "## Detected Package Scripts\n\n"
        + npm_commands
        + "\n\n## Install\n\nTODO\n"
        + "\n## Run Locally\n\nTODO\n"
        + "\n## Build\n\nTODO\n"
        + "\n## Lint And Format\n\nTODO\n"
        + "\n## Typecheck\n\nTODO\n"
        + "\n## Test\n\nTODO\n"
        + "\n## Database And Migrations\n\nTODO\n"
    )


def coding_standards_content():
    return """# Coding Standards

## Language And Framework Conventions

TODO: infer from source files, manifests, and configs.

## Naming

TODO: file, class, function, variable, route, and data-field naming conventions.

## Module Boundaries

TODO: describe allowed dependencies and cross-module rules.

## Error Handling

TODO: describe business errors, exceptions, logging, and user-visible errors.

## Data Access

TODO: describe ORM/query/repository patterns, transactions, migrations, and cache usage.

## Testing

TODO: describe test framework, locations, mocks, fixtures, and naming.

## Formatting And Tooling

TODO: describe formatter, linter, type checker, and build/test commands.

## Agent Rules

- Read relevant knowledge-base files before editing code.
- Prefer existing repo patterns over new abstractions.
- Do not hard-code uncertain business rules; add them to `Open Questions`.
- Update affected knowledge-base files after meaningful code changes.
"""


def workflows_content():
    return """# Workflows

## Add Or Change An API

TODO

## Add Or Change UI

TODO

## Add Or Change Data Model

TODO

## Add Or Change Background Job

TODO

## Add Or Change Configuration

TODO
"""


def architecture_content():
    return """# Architecture

## Overview

TODO

## Boundaries

TODO

## Request Flow

TODO

## State Management

TODO

## Persistence

TODO

## Authentication And Authorization

TODO

## Error Handling

TODO

## External Integrations

TODO
"""


def testing_content():
    return """# Testing

## Test Types

TODO

## Test Locations

TODO

## Fixtures And Mocks

TODO

## Commands

TODO

## Expectations By Change Type

TODO
"""


def modules_content(modules):
    return (
        "# Modules\n\n"
        + ("\n".join(f"- `{module}`: TODO" for module in modules) if modules else "- TODO\n")
        + "\n"
    )


def spec_content(module):
    return f"""# Module Spec: {module}

## Purpose

TODO

## Main Business Logic

TODO

## Key Files

TODO

## Public Interfaces

TODO

## Data Model

TODO

## Dependencies

TODO

## Side Effects

TODO

## Tests

TODO

## Coding Standards Notes

Only list module-specific conventions that differ from `../../coding-standards.md`.

## Deeper References

- `design.md`: architecture, boundaries, and tradeoffs.
- `implementation-notes.md`: detailed call flow and edge cases.
- `decisions.md`: important historical decisions.

## Open Questions

TODO
"""


def design_content(module):
    return f"""# Module Design: {module}

## Design Intent

TODO

## Boundaries

TODO

## Tradeoffs

TODO

## Evolution Notes

TODO
"""


def implementation_notes_content(module):
    return f"""# Implementation Notes: {module}

## Detailed Flow

TODO

## State And Transactions

TODO

## Caching And Concurrency

TODO

## Edge Cases

TODO
"""


def decisions_content(module):
    return f"""# Decisions: {module}

## Active Decisions

TODO

## Historical Notes

TODO
"""


def main():
    parser = argparse.ArgumentParser(description="Scaffold repository knowledge-base files.")
    parser.add_argument("--root", default=".", help="Repository root. Defaults to current directory.")
    parser.add_argument("--force", action="store_true", help="Overwrite existing generated files.")
    parser.add_argument("--module-depth", type=int, default=1, help="Module detection depth under common module roots.")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    kb = root / "knowledge-base"
    modules_dir = kb / "modules"
    changes_dir = kb / "changes"

    manifests = existing_files(root, MANIFESTS)
    configs = existing_files(root, CONFIGS)
    frameworks = detect_frameworks(root)
    scripts = package_scripts(root)
    modules = detect_modules(root, max(args.module_depth, 1))

    created = []
    for path, content in [
        (kb / "README.md", readme_content()),
        (kb / "repo-map.md", repo_map_content(root, manifests, configs, modules)),
        (kb / "tech-stack.md", tech_stack_content(manifests, configs, frameworks)),
        (kb / "commands.md", commands_content(scripts)),
        (kb / "coding-standards.md", coding_standards_content()),
        (kb / "workflows.md", workflows_content()),
        (kb / "architecture.md", architecture_content()),
        (kb / "testing.md", testing_content()),
        (kb / "modules.md", modules_content(modules)),
    ]:
        if write_file(path, content, force=args.force):
            created.append(path)

    changes_dir.mkdir(parents=True, exist_ok=True)

    for module in modules:
        module_dir = modules_dir / safe_name(module)
        for filename, content in [
            ("spec.md", spec_content(module)),
            ("design.md", design_content(module)),
            ("implementation-notes.md", implementation_notes_content(module)),
            ("decisions.md", decisions_content(module)),
        ]:
            path = module_dir / filename
            if write_file(path, content, force=args.force):
                created.append(path)

    print(f"Knowledge base path: {kb}")
    print(f"Detected modules: {len(modules)}")
    print(f"Files created or overwritten: {len(created)}")
    for path in created:
        print(f"- {path.relative_to(root).as_posix()}")


if __name__ == "__main__":
    main()
