---
name: ai-native-workflow-bootstrap
description: >
  Bootstrap a 5-layer AI-native development workflow in any codebase.
  Use when setting up CLAUDE.md, commit wrapper scripts, pre-commit hooks,
  smart CI, agent skills, per-module boundary guides, or frontend-backend
  API contract workflows.
argument-hint: "[--dry-run]"
disable-model-invocation: true
allowed-tools: Read Glob Grep Bash(mkdir *) Bash(chmod *) Bash(ln *) Bash(git config *) Bash(${CLAUDE_SKILL_DIR}/scripts/bootstrap-ai-workflow.sh *)
---

# AI-Native Workflow Bootstrap

Use this skill to transform any codebase into an AI-native development workflow where multiple AI agents can work safely and independently.

## Decision Tree

Start here. Pick the row that matches your situation:

| Team Size | Project State | Start With | Then Add |
|-----------|--------------|------------|----------|
| Solo | Greenfield | Layer 4 (CLAUDE.md) | Layer 2 (committer) when patterns stabilize |
| Solo | Existing codebase | Layer 4, then Layer 1 (boundaries in CLAUDE.md) | Layer 2 |
| 2-5 people | Any | Layer 4, Layer 2, Layer 5 (skills) | Layer 3 (CI) when CI exists |
| 6+ people | Any | All 5 layers; start Layer 4 + Layer 1 | Layer 2, Layer 3, Layer 5 in order |

Layer 4 (instruction hierarchy) always comes first. Everything else builds on it.

## Layer 1 -- Code Architecture Constraints

Codify module boundaries so AI agents cannot accidentally cross them. Write these directly into CLAUDE.md and per-module AGENTS.md files.

What to define:
- Which directories own which concerns
- Which imports are allowed across which boundaries
- Type system rules (strict typing, banned patterns, schema validation)

Template -- add this section to your root CLAUDE.md:

```markdown
## Architecture Boundaries

- `src/auth/` owns authentication and session management. Do not import from `src/payment/` directly.
- `src/payment/` owns billing and subscriptions. Access auth through `src/auth/index.ts` barrel only.
- `src/common/` owns shared utilities. Any module may import from here.
- Do not create circular dependencies between modules.
- Prefer strict typing; avoid `any`. Use `zod` schemas at external boundaries (API input, config, webhooks).
```

## Layer 2 -- Local Guard Tools

Three tools in priority order:

### 2a. Commit Wrapper Script

Prevents AI from running `git add .` and staging the entire repo. Create as `scripts/committer`:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() { printf 'Usage: %s "commit message" file [file ...]\n' "$(basename "$0")" >&2; exit 2; }
[ "$#" -lt 2 ] && usage

commit_message=$1; shift

# Block dangerous patterns
for file in "$@"; do
  case "$file" in
    .) printf 'Error: "." not allowed; list specific paths\n' >&2; exit 1 ;;
    *node_modules*) printf 'Error: node_modules not allowed: %s\n' "$file" >&2; exit 1 ;;
    *.env|*.env.*) printf 'Error: env files not allowed: %s\n' "$file" >&2; exit 1 ;;
  esac
done

# Verify files exist
for file in "$@"; do
  [ -e "$file" ] || { printf 'Error: file not found: %s\n' "$file" >&2; exit 1; }
done

# Unstage everything, then stage only named files
git restore --staged :/ 2>/dev/null || true
git add --force -- "$@"

if git diff --staged --quiet; then
  printf 'Warning: no staged changes for: %s\n' "$*" >&2; exit 1
fi

if [ "${FAST_COMMIT:-0}" = "1" ]; then
  FAST_COMMIT=1 git commit -m "$commit_message"
else
  git commit -m "$commit_message"
fi

printf 'Committed "%s" with %d file(s)\n' "$commit_message" "$#"
```

After creating: `chmod +x scripts/committer`

Then add to your CLAUDE.md:
```
- Create commits with `scripts/committer "<msg>" <file...>`; avoid manual `git add`/`git commit`.
```

### 2b. Pre-commit Hook

Create as `git-hooks/pre-commit` (or `.husky/pre-commit` if using Husky):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Skip heavy checks in fast mode
if [ "${FAST_COMMIT:-0}" = "1" ]; then
  printf '[pre-commit] FAST_COMMIT=1, skipping repo-wide checks\n'
  exit 0
fi

# Get staged files
staged=$(git diff --cached --name-only --diff-filter=ACMR)
[ -z "$staged" ] && exit 0

# Run lint on staged files only (adapt command to your stack)
# Node/TS: npx eslint $staged
# Python:  ruff check $staged
# Go:      golangci-lint run --new-from-rev=HEAD
# Flutter: dart analyze

# Run project-wide check
# <package-manager> check
```

Configure git to use it: `git config core.hooksPath git-hooks`

### 2c. Heavy-Check Lock (optional, for larger projects)

When multiple agents run on the same machine, expensive commands (type-check, full test suite) can compete for resources. Implement a file-based lock:
- Lock file at `.git/heavy-check.lock` with PID and timestamp
- 10-minute timeout, 500ms poll interval
- Skip lock for fast/scoped commands

This prevents two agents from running `pnpm build` simultaneously and causing OOM.

## Layer 3 -- CI/CD Automation

Four patterns to adopt in your CI pipeline:

### 3a. Smart CI (changed-scope detection)

A preflight job detects which modules changed and only runs relevant tests:

```yaml
preflight:
  runs-on: ubuntu-latest
  outputs:
    auth-changed: ${{ steps.scope.outputs.auth }}
    payment-changed: ${{ steps.scope.outputs.payment }}
  steps:
    - uses: actions/checkout@v4
    - id: scope
      run: |
        changed=$(git diff --name-only ${{ github.event.before }} ${{ github.sha }})
        echo "auth=$(echo "$changed" | grep -q '^src/auth/' && echo true || echo false)" >> $GITHUB_OUTPUT
        echo "payment=$(echo "$changed" | grep -q '^src/payment/' && echo true || echo false)" >> $GITHUB_OUTPUT

test-auth:
  needs: preflight
  if: needs.preflight.outputs.auth-changed == 'true'
  # ...run auth tests only
```

### 3b. Auto-labeling

Use `actions/labeler` to tag PRs by changed files (e.g., `module:auth`, `module:payment`, `size:S`).

### 3c. Stale Management

Use `actions/stale` to auto-close inactive issues (7 days) and PRs (5 days). Exempt labels: `maintainer`, `pinned`, `security`.

### 3d. Auto-response on Label

When a triage label like `r:support` is applied, a workflow posts a templated comment and closes the issue. Reduces maintainer burden.

## Layer 4 -- Instruction Hierarchy

The most critical layer. Two file types:

### 4a. Root CLAUDE.md

Auto-loaded by Claude Code at every conversation start. Keep it under 40k characters. Template:

```markdown
# CLAUDE.md

This file provides guidance to AI coding agents working in this repository.

## Project Structure

- Source: `src/` — <brief description of subdirectories>
- Tests: colocated `*.test.*` or `test/` directory
- Docs: `docs/`

## Build & Test Commands

- Install: `<pm> install`
- Build: `<pm> build`
- Test: `<pm> test`
- Lint: `<pm> lint`
- Format: `<pm> format`

## Coding Style

- Language: <language>. Prefer strict typing.
- Formatting: <tool>. Linting: <tool>.
- Add brief comments for non-obvious logic only.

## Architecture Boundaries

- <module A>: <what it owns>. See `src/<A>/AGENTS.md`.
- <module B>: <what it owns>. See `src/<B>/AGENTS.md`.

## Commit Guidelines

- Use `scripts/committer "<msg>" <file...>` for scoped commits.
- Concise, action-oriented messages (e.g., `feat: add verbose flag`).

## Agent Skills

- Use `$<skill-name>` at `.claude/skills/<skill-name>/SKILL.md` for <purpose>.
```

Design rules:
- Keep under 40k chars (Claude Code warns above this)
- Use bullet lists, not prose
- Include exact commands (AI can copy-paste)
- Reference per-module guides with "see `<path>/AGENTS.md`"
- Do not duplicate content from per-module AGENTS.md files

### 4b. Per-Module AGENTS.md

One per important module. Loaded on-demand when an agent works in that directory. Template:

```markdown
# <Module Name> Boundary

This directory owns <purpose>.

## Public Contracts

- Types: `types.ts`
- API barrel: `index.ts` (only import this from outside)
- Docs: `docs/<module>.md`

## Boundary Rules

- Do not import from `../<other-module>/` directly.
- Export public API through `./index.ts` only.
- Keep <concern A> separate from <concern B>.

## Verification

- Run tests: `<pm> test src/<module>/`
- Type-check: `<pm> tsgo`
```

Always create a symlink: `ln -s AGENTS.md CLAUDE.md` in the same directory.

## Layer 5 -- Agent Skill System

For tasks that repeat (PR review, deployment, migration), create standardized skills.

Directory convention: `.claude/skills/<name>/SKILL.md`

Skill skeleton:

```markdown
---
name: <project>-<task>
description: <When to use this skill. Front-load the key trigger phrase.>
argument-hint: "[optional-args]"
disable-model-invocation: true
allowed-tools: Read Grep Bash(npm test *)
---

# <Task Name>

Use this skill for <scope>.

## Prerequisites

- <What to read or check before starting>

## Workflow

1. <Step 1>
2. <Step 2>
3. <Step 3>

## Verification

- <How to confirm the task succeeded>

## Common Pitfalls

- <Mistake agents commonly make>
- <Edge case to watch for>
```

Key frontmatter fields:

| Field | When to use |
|-------|------------|
| `disable-model-invocation: true` | Manual-only tasks like deploy, publish, send messages |
| `allowed-tools` | Pre-approve tools so Claude doesn't ask for permission every time |
| `argument-hint` | Show hint in `/` autocomplete (e.g., `[issue-number]`) |
| `context: fork` | Run in isolated subagent (no conversation history) |
| `paths` | Auto-activate only when working with matching files (e.g., `"**/*.ts"`) |

Use `$ARGUMENTS` in skill content to reference arguments passed by the user (e.g., `/deploy staging` → `$ARGUMENTS` = `staging`).

Skill locations:
- `.claude/skills/<name>/SKILL.md` — project-level (commit to git, team shares)
- `~/.claude/skills/<name>/SKILL.md` — personal-level (all your projects)

Good first skills to create:
- `<project>-deploy` -- deployment to staging/production
- `<project>-pr-review` -- PR review checklist and decision tree
- `<project>-db-migration` -- database migration safety steps

## Frontend-Backend Collaboration

When frontend and backend are separate projects (different languages or repos), use the backend's auto-generated API spec as the single source of truth. Do NOT maintain hand-written contract documents.

### Pattern: Backend generates, frontend consumes

```
Backend implements endpoints (with API doc decorators)
  → Export spec to shared location (e.g., ../contracts/swagger.json)
  → Frontend agent reads spec to implement matching code
```

### Setup by stack

**NestJS + Swagger**:
- Use `@ApiTags`, `@ApiOperation`, `@ApiProperty`, `@ApiResponse` decorators on all controllers and DTOs.
- Add an export script that boots the app, generates the OpenAPI document, and writes it to a shared path:
  ```bash
  npx ts-node -r tsconfig-paths/register scripts/export-swagger.ts
  # → ../contracts/swagger.json
  ```
- In backend CLAUDE.md: "After adding/changing endpoints, run export script to update swagger.json."
- In frontend CLAUDE.md: "Read `../contracts/swagger.json` for exact paths, parameters, and response schemas."

**Django / FastAPI / Spring Boot**: Same pattern -- use the framework's built-in OpenAPI export.

**GraphQL**: Export the schema (`schema.graphql`) instead of swagger.json.

**gRPC / Protobuf**: The `.proto` files ARE the contract. Share them directly.

### Workflow for new features

1. Backend agent implements the endpoints with full API doc decorators
2. Run the export script to generate/update the spec file
3. Frontend agent reads the spec and implements matching Service + Model code
4. No manual documentation needed -- the backend code IS the documentation

### What to put in each CLAUDE.md

Backend:
```markdown
## API Contract
- All controllers must use Swagger/OpenAPI decorators.
- After adding/changing endpoints: `<export command>`
- This writes `../contracts/<spec-file>` for the frontend to consume.
```

Frontend:
```markdown
## API Contract
- Backend API spec is at `../contracts/<spec-file>` (auto-generated).
- Read the spec for exact paths, parameters, and response schemas before implementing.
- If the spec is outdated, ask the user to regenerate from the backend.
```

## Multi-Agent Safety

When running multiple AI agents on the same codebase:

- Each agent uses `scripts/committer` to commit only its own files
- Do not create/apply/drop `git stash` entries (other agents may be working)
- Do not switch branches unless explicitly requested
- Do not create/remove `git worktree` checkouts unless explicitly requested
- When you see unrecognized files from another agent, ignore them and continue
- Prefer grouped commit/pull --rebase/push cycles over many tiny syncs
- If lint/format diffs are formatting-only, auto-resolve without asking
- Scope reports to your own edits; avoid disclaimers about other agents' files

Add these rules to your root CLAUDE.md under a "Multi-Agent Safety" section.

## Bootstrap Checklist

Recommended implementation order:

1. Create root `CLAUDE.md` with project structure, build commands, coding style
2. Create `AGENTS.md` symlink: `ln -s CLAUDE.md AGENTS.md` (or vice versa)
3. Add `scripts/committer` wrapper, run `chmod +x`
4. Configure git hooks path: `git config core.hooksPath git-hooks`
5. Add `git-hooks/pre-commit` with lint/format on staged files
6. Create one per-module `AGENTS.md` + symlink for your most complex module
7. If frontend-backend split: add API spec export script + shared `contracts/` directory
8. Add smart-CI preflight job to existing CI pipeline
9. Add stale-management workflow
10. Add auto-labeler workflow
11. Create `.claude/skills/` directory
12. Write first skill for your most repetitive maintenance task
13. Review and iterate after 2 weeks of AI agent usage

## Stack-Specific Notes

- **Node/TypeScript**: Use `oxlint`/`eslint` + `oxfmt`/`prettier`. Smart CI splits by `src/` subdirs. Pre-commit: type-check staged files with `tsc --noEmit`.
- **Python**: Use `ruff` for lint+format, `mypy`/`pyright` for types. Smart CI splits by package dirs. Pre-commit: `ruff check --fix` on staged files.
- **Go**: Use `golangci-lint`. Smart CI via `go list ./...` on changed packages. Pre-commit: `go vet` + `gofmt`.
- **Flutter/Dart**: Use `dart analyze` + `dart format`. Smart CI splits by `lib/`, `test/`, platform dirs. Pre-commit: `dart analyze` on changed files.
- **NestJS**: Module system naturally supports boundaries. Map each NestJS module to one AGENTS.md. Use barrel `index.ts` exports as the enforced public API.
- **Monorepo**: Per-package AGENTS.md files. Workspace-aware changed-scope detection in CI. Separate test matrices per package. Consider heavy-check lock for shared machines.
