param(
    [string]$Root = ".",
    [switch]$Force,
    [int]$ModuleDepth = 1
)

$ErrorActionPreference = "Stop"

$IgnoreDirs = @(
    ".git", ".hg", ".svn", ".idea", ".vscode", ".cache", ".next", ".nuxt", ".turbo",
    ".venv", "venv", "env", "node_modules", "dist", "build", "out", "coverage",
    "target", "vendor", "__pycache__"
)

$Manifests = @(
    "package.json", "pnpm-lock.yaml", "yarn.lock", "package-lock.json", "bun.lockb",
    "pyproject.toml", "requirements.txt", "Pipfile", "poetry.lock", "go.mod",
    "Cargo.toml", "pom.xml", "build.gradle", "settings.gradle", "Gemfile",
    "composer.json", "deno.json", "deno.jsonc", "mix.exs", "pubspec.yaml"
)

$Configs = @(
    "tsconfig.json", "vite.config.ts", "vite.config.js", "next.config.js", "next.config.mjs",
    "nuxt.config.ts", "tailwind.config.js", "tailwind.config.ts", "eslint.config.js",
    ".eslintrc", ".eslintrc.json", "prettier.config.js", ".prettierrc", "jest.config.js",
    "vitest.config.ts", "playwright.config.ts", "pytest.ini", "ruff.toml", "mypy.ini",
    "Makefile", "Dockerfile", "docker-compose.yml"
)

$ModuleRoots = @(
    "src", "app", "apps", "packages", "libs", "modules", "services", "server",
    "client", "frontend", "backend", "api", "cmd", "internal", "pkg"
)

$SourceExtensions = @(
    ".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".py", ".go", ".rs", ".java",
    ".kt", ".cs", ".rb", ".php", ".ex", ".exs", ".swift", ".dart"
)

function Get-RelativePath {
    param([string]$Path, [string]$Base)
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $resolvedBase = [System.IO.Path]::GetFullPath($Base)
    if (-not $resolvedBase.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $resolvedBase = $resolvedBase + [System.IO.Path]::DirectorySeparatorChar
    }
    $baseUri = New-Object System.Uri($resolvedBase)
    $pathUri = New-Object System.Uri($resolvedPath)
    $relative = [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString())
    return $relative.Replace("\", "/")
}

function Write-KbFile {
    param([string]$Path, [string]$Content)
    if ((Test-Path $Path) -and -not $Force) {
        return $false
    }
    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Set-Content -Path $Path -Value $Content -Encoding UTF8
    return $true
}

function Get-SafeName {
    param([string]$Name)
    $safe = ($Name.Trim("/\") -replace "[^A-Za-z0-9._-]+", "__").Trim("._-")
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return "root"
    }
    return $safe
}

function Get-ExistingFiles {
    param([string]$RepoRoot, [string[]]$Names)
    $result = @()
    foreach ($name in $Names) {
        if (Test-Path (Join-Path $RepoRoot $name)) {
            $result += $name
        }
    }
    return $result
}

function Get-PackageJson {
    param([string]$RepoRoot)
    $path = Join-Path $RepoRoot "package.json"
    if (-not (Test-Path $path)) {
        return $null
    }
    try {
        return Get-Content -Raw -Path $path | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Get-DetectedFrameworks {
    param([string]$RepoRoot)
    $frameworks = New-Object System.Collections.Generic.HashSet[string]
    $pkg = Get-PackageJson $RepoRoot
    if ($null -ne $pkg) {
        $deps = @{}
        foreach ($section in @("dependencies", "devDependencies", "peerDependencies")) {
            if ($pkg.PSObject.Properties.Name -contains $section) {
                foreach ($prop in $pkg.$section.PSObject.Properties) {
                    $deps[$prop.Name] = $prop.Value
                }
            }
        }
        foreach ($candidate in @(
            "react", "next", "vue", "nuxt", "svelte", "@sveltejs/kit", "angular",
            "@angular/core", "express", "fastify", "koa", "@nestjs/core", "vite",
            "typescript", "tailwindcss", "jest", "vitest", "playwright", "cypress",
            "prisma", "drizzle-orm"
        )) {
            if ($deps.ContainsKey($candidate)) {
                [void]$frameworks.Add($candidate)
            }
        }
    }
    if ((Test-Path (Join-Path $RepoRoot "pyproject.toml")) -or (Test-Path (Join-Path $RepoRoot "requirements.txt"))) {
        [void]$frameworks.Add("python")
    }
    if (Test-Path (Join-Path $RepoRoot "go.mod")) {
        [void]$frameworks.Add("go")
    }
    if (Test-Path (Join-Path $RepoRoot "Cargo.toml")) {
        [void]$frameworks.Add("rust")
    }
    if ((Test-Path (Join-Path $RepoRoot "pom.xml")) -or (Test-Path (Join-Path $RepoRoot "build.gradle"))) {
        [void]$frameworks.Add("jvm")
    }
    return @($frameworks) | Sort-Object
}

function Get-PackageScripts {
    param([string]$RepoRoot)
    $pkg = Get-PackageJson $RepoRoot
    $scripts = @{}
    if ($null -ne $pkg -and ($pkg.PSObject.Properties.Name -contains "scripts")) {
        foreach ($prop in $pkg.scripts.PSObject.Properties) {
            $scripts[$prop.Name] = [string]$prop.Value
        }
    }
    return $scripts
}

function Test-DirHasSource {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return $false
    }
    foreach ($child in Get-ChildItem -Force -Path $Path -File -ErrorAction SilentlyContinue) {
        if ($SourceExtensions -contains $child.Extension) {
            return $true
        }
    }
    return $false
}

function Get-DetectedModules {
    param([string]$RepoRoot, [int]$Depth)
    $set = New-Object System.Collections.Generic.HashSet[string]
    foreach ($rootName in $ModuleRoots) {
        $base = Join-Path $RepoRoot $rootName
        if (-not (Test-Path $base)) {
            continue
        }
        $children = Get-ChildItem -Force -Path $base -Directory |
            Where-Object { ($IgnoreDirs -notcontains $_.Name) -and (-not $_.Name.StartsWith(".")) }
        if ($children.Count -eq 0) {
            [void]$set.Add((Get-RelativePath $base $RepoRoot))
            continue
        }
        foreach ($child in $children) {
            if ($Depth -le 1) {
                [void]$set.Add((Get-RelativePath $child.FullName $RepoRoot))
                continue
            }
            $grandchildren = Get-ChildItem -Force -Path $child.FullName -Directory |
                Where-Object { ($IgnoreDirs -notcontains $_.Name) -and (-not $_.Name.StartsWith(".")) }
            if ($grandchildren.Count -gt 0) {
                foreach ($grandchild in $grandchildren) {
                    if (Test-DirHasSource $grandchild.FullName) {
                        [void]$set.Add((Get-RelativePath $grandchild.FullName $RepoRoot))
                    }
                }
                [void]$set.Add((Get-RelativePath $child.FullName $RepoRoot))
            }
            else {
                [void]$set.Add((Get-RelativePath $child.FullName $RepoRoot))
            }
        }
    }
    if ($set.Count -eq 0) {
        foreach ($child in Get-ChildItem -Force -Path $RepoRoot -Directory) {
            if (($IgnoreDirs -contains $child.Name) -or $child.Name.StartsWith(".")) {
                continue
            }
            if (Test-DirHasSource $child.FullName) {
                [void]$set.Add((Get-RelativePath $child.FullName $RepoRoot))
            }
        }
    }
    return @($set) | Sort-Object
}

function Join-LinesOrTodo {
    param([string[]]$Items, [string]$Format = '- `{0}`')
    if ($Items.Count -eq 0) {
        return "- TODO"
    }
    return (($Items | ForEach-Object { $Format -f $_ }) -join "`n")
}

function Get-ReadmeContent {
@"
# Knowledge Base

## Agent Reading Order

For any code task:
1. Read ``commands.md``.
2. Read ``coding-standards.md``.
3. Read ``repo-map.md``.
4. Read affected module specs under ``modules/``.

For architecture changes:
1. Read ``architecture.md``.
2. Read affected module ``design.md`` and ``decisions.md``.

For API changes:
1. Read ``api-surface.md`` if present.
2. Read affected module specs.
3. Update tests and change records.

## Update Rule

After meaningful code changes, update affected knowledge-base files before finishing.

Do not update knowledge-base files for formatting-only changes, trivial copy changes, or edits with no behavioral meaning.
"@
}

function Get-RepoMapContent {
    param([string]$RepoRoot, [string[]]$FoundManifests, [string[]]$FoundConfigs, [string[]]$Modules)
    $topDirs = Get-ChildItem -Force -Path $RepoRoot -Directory |
        Where-Object { ($IgnoreDirs -notcontains $_.Name) -and (-not $_.Name.StartsWith(".")) } |
        Sort-Object Name |
        ForEach-Object { Get-RelativePath $_.FullName $RepoRoot }
    $topDirText = if ($topDirs.Count -gt 0) { (($topDirs | ForEach-Object { "- ``$($_)``: TODO" }) -join "`n") } else { "- TODO" }
    $manifestText = Join-LinesOrTodo $FoundManifests
    $configText = Join-LinesOrTodo $FoundConfigs
    $moduleText = Join-LinesOrTodo $Modules
@"
# Repo Map

## Top-Level Directories

$topDirText

## Important Manifests

$manifestText

## Important Configs

$configText

## Detected Module Roots

$moduleText
"@
}

function Get-TechStackContent {
    param([string[]]$FoundManifests, [string[]]$FoundConfigs, [string[]]$Frameworks)
    $manifestText = Join-LinesOrTodo $FoundManifests
    $configText = Join-LinesOrTodo $FoundConfigs
    $frameworkText = if ($Frameworks.Count -gt 0) { (($Frameworks | ForEach-Object { "- ``$($_)``" }) -join "`n") } else { "- TODO: inspect source imports and configs." }
@"
# Tech Stack

## Detected Manifests

$manifestText

## Detected Configs

$configText

## Detected Languages And Frameworks

$frameworkText

## Runtime And Package Managers

TODO
"@
}

function Get-CommandsContent {
    param([hashtable]$Scripts)
    if ($Scripts.Count -gt 0) {
        $scriptText = (($Scripts.Keys | Sort-Object | ForEach-Object { "- ``npm run $_``: ``$($Scripts[$_])``" }) -join "`n")
    }
    else {
        $scriptText = "- TODO: inspect package manager, Makefile, task runner, or project docs."
    }
@"
# Commands

## Detected Package Scripts

$scriptText

## Install

TODO

## Run Locally

TODO

## Build

TODO

## Lint And Format

TODO

## Typecheck

TODO

## Test

TODO

## Database And Migrations

TODO
"@
}

function Get-CodingStandardsContent {
@"
# Coding Standards

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
- Do not hard-code uncertain business rules; add them to ``Open Questions``.
- Update affected knowledge-base files after meaningful code changes.
"@
}

function Get-WorkflowsContent {
@"
# Workflows

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
"@
}

function Get-ArchitectureContent {
@"
# Architecture

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
"@
}

function Get-TestingContent {
@"
# Testing

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
"@
}

function Get-ModulesContent {
    param([string[]]$Modules)
    $moduleText = if ($Modules.Count -gt 0) { (($Modules | ForEach-Object { "- ``$($_)``: TODO" }) -join "`n") } else { "- TODO" }
@"
# Modules

$moduleText
"@
}

function Get-SpecContent {
    param([string]$Module)
@"
# Module Spec: $Module

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

Only list module-specific conventions that differ from ``../../coding-standards.md``.

## Deeper References

- ``design.md``: architecture, boundaries, and tradeoffs.
- ``implementation-notes.md``: detailed call flow and edge cases.
- ``decisions.md``: important historical decisions.

## Open Questions

TODO
"@
}

function Get-DesignContent {
    param([string]$Module)
@"
# Module Design: $Module

## Design Intent

TODO

## Boundaries

TODO

## Tradeoffs

TODO

## Evolution Notes

TODO
"@
}

function Get-ImplementationNotesContent {
    param([string]$Module)
@"
# Implementation Notes: $Module

## Detailed Flow

TODO

## State And Transactions

TODO

## Caching And Concurrency

TODO

## Edge Cases

TODO
"@
}

function Get-DecisionsContent {
    param([string]$Module)
@"
# Decisions: $Module

## Active Decisions

TODO

## Historical Notes

TODO
"@
}

$RepoRoot = [System.IO.Path]::GetFullPath($Root)
$Kb = Join-Path $RepoRoot "knowledge-base"
$ModulesDir = Join-Path $Kb "modules"
$ChangesDir = Join-Path $Kb "changes"

$FoundManifests = Get-ExistingFiles $RepoRoot $Manifests
$FoundConfigs = Get-ExistingFiles $RepoRoot $Configs
$Frameworks = Get-DetectedFrameworks $RepoRoot
$Scripts = Get-PackageScripts $RepoRoot
$Modules = Get-DetectedModules $RepoRoot ([Math]::Max($ModuleDepth, 1))

$Created = New-Object System.Collections.Generic.List[string]

$globalFiles = @(
    @{ Path = Join-Path $Kb "README.md"; Content = Get-ReadmeContent },
    @{ Path = Join-Path $Kb "repo-map.md"; Content = Get-RepoMapContent $RepoRoot $FoundManifests $FoundConfigs $Modules },
    @{ Path = Join-Path $Kb "tech-stack.md"; Content = Get-TechStackContent $FoundManifests $FoundConfigs $Frameworks },
    @{ Path = Join-Path $Kb "commands.md"; Content = Get-CommandsContent $Scripts },
    @{ Path = Join-Path $Kb "coding-standards.md"; Content = Get-CodingStandardsContent },
    @{ Path = Join-Path $Kb "workflows.md"; Content = Get-WorkflowsContent },
    @{ Path = Join-Path $Kb "architecture.md"; Content = Get-ArchitectureContent },
    @{ Path = Join-Path $Kb "testing.md"; Content = Get-TestingContent },
    @{ Path = Join-Path $Kb "modules.md"; Content = Get-ModulesContent $Modules }
)

foreach ($file in $globalFiles) {
    if (Write-KbFile $file.Path $file.Content) {
        $Created.Add($file.Path) | Out-Null
    }
}

New-Item -ItemType Directory -Force -Path $ChangesDir | Out-Null

foreach ($module in $Modules) {
    $moduleDir = Join-Path $ModulesDir (Get-SafeName $module)
    $moduleFiles = @(
        @{ Name = "spec.md"; Content = Get-SpecContent $module },
        @{ Name = "design.md"; Content = Get-DesignContent $module },
        @{ Name = "implementation-notes.md"; Content = Get-ImplementationNotesContent $module },
        @{ Name = "decisions.md"; Content = Get-DecisionsContent $module }
    )
    foreach ($file in $moduleFiles) {
        $path = Join-Path $moduleDir $file.Name
        if (Write-KbFile $path $file.Content) {
            $Created.Add($path) | Out-Null
        }
    }
}

Write-Output "Knowledge base path: $Kb"
Write-Output "Detected modules: $($Modules.Count)"
Write-Output "Files created or overwritten: $($Created.Count)"
foreach ($path in $Created) {
    Write-Output "- $(Get-RelativePath $path $RepoRoot)"
}
