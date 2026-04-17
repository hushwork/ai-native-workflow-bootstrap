#!/usr/bin/env bash
# bootstrap-ai-workflow.sh -- Generate starter files for an AI-native development workflow.
# Usage: bootstrap-ai-workflow.sh [--dry-run] [--skip-ci]
# Run from your project root directory.

set -euo pipefail

DRY_RUN=false
SKIP_CI=false

while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --skip-ci) SKIP_CI=true; shift ;;
    --help|-h)
      printf 'Usage: %s [--dry-run] [--skip-ci]\n' "$(basename "$0")"
      printf '  --dry-run   Print what would be created without writing\n'
      printf '  --skip-ci   Skip CI workflow generation\n'
      exit 0
      ;;
    *) printf 'Unknown flag: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# --- Stack detection ---

STACK="unknown"
PM="npm"
SRC_DIR="src"
TEST_CMD="npm test"
LINT_CMD="npm run lint"
BUILD_CMD="npm run build"
FORMAT_CMD="npm run format"

if [ -f "package.json" ]; then
  STACK="node"
  if [ -f "pnpm-lock.yaml" ]; then PM="pnpm"
  elif [ -f "yarn.lock" ]; then PM="yarn"
  elif [ -f "bun.lockb" ]; then PM="bun"
  fi
  TEST_CMD="$PM test"
  LINT_CMD="$PM lint"
  BUILD_CMD="$PM build"
  FORMAT_CMD="$PM format"
elif [ -f "pubspec.yaml" ]; then
  STACK="flutter"; PM="flutter"; SRC_DIR="lib"
  TEST_CMD="flutter test"; LINT_CMD="dart analyze"; BUILD_CMD="flutter build"; FORMAT_CMD="dart format ."
elif [ -f "go.mod" ]; then
  STACK="go"; PM="go"; SRC_DIR="."
  TEST_CMD="go test ./..."; LINT_CMD="golangci-lint run"; BUILD_CMD="go build ./..."; FORMAT_CMD="gofmt -w ."
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  STACK="python"; PM="pip"; SRC_DIR="src"
  TEST_CMD="pytest"; LINT_CMD="ruff check ."; BUILD_CMD="python -m build"; FORMAT_CMD="ruff format ."
elif [ -f "Cargo.toml" ]; then
  STACK="rust"; PM="cargo"; SRC_DIR="src"
  TEST_CMD="cargo test"; LINT_CMD="cargo clippy"; BUILD_CMD="cargo build"; FORMAT_CMD="cargo fmt"
fi

PROJECT_NAME=$(basename "$(pwd)")

printf '=== AI-Native Workflow Bootstrap ===\n'
printf 'Detected stack: %s\n' "$STACK"
printf 'Package manager: %s\n' "$PM"
printf 'Project name: %s\n' "$PROJECT_NAME"
printf 'Source directory: %s\n' "$SRC_DIR"
printf '\n'

# --- File writer ---

FILES_CREATED=0

write_file() {
  local path=$1
  local content=$2

  if [ -e "$path" ]; then
    printf '[skip] %s (already exists)\n' "$path"
    return
  fi

  if [ "$DRY_RUN" = true ]; then
    printf '[dry-run] would create: %s\n' "$path"
  else
    mkdir -p "$(dirname "$path")"
    printf '%s' "$content" > "$path"
    printf '[created] %s\n' "$path"
  fi
  FILES_CREATED=$((FILES_CREATED + 1))
}

make_executable() {
  local path=$1
  if [ "$DRY_RUN" = false ] && [ -e "$path" ]; then
    chmod +x "$path"
  fi
}

make_symlink() {
  local target=$1
  local link=$2

  if [ -e "$link" ] || [ -L "$link" ]; then
    printf '[skip] %s (already exists)\n' "$link"
    return
  fi

  if [ "$DRY_RUN" = true ]; then
    printf '[dry-run] would symlink: %s -> %s\n' "$link" "$target"
  else
    ln -s "$target" "$link"
    printf '[symlink] %s -> %s\n' "$link" "$target"
  fi
}

# --- Generate root CLAUDE.md ---

write_file "CLAUDE.md" "# CLAUDE.md

This file provides guidance to AI coding agents working in this repository.

## Project Structure

- Source: \`${SRC_DIR}/\`
- Tests: colocated test files
- Docs: \`docs/\`

## Build & Test Commands

- Install: \`${PM} install\`
- Build: \`${BUILD_CMD}\`
- Test: \`${TEST_CMD}\`
- Lint: \`${LINT_CMD}\`
- Format: \`${FORMAT_CMD}\`

## Coding Style

- Prefer strict typing; avoid \`any\` or equivalent loose types.
- Add brief comments for non-obvious logic only.

## Architecture Boundaries

- Document module boundaries here as the project grows.
- See per-module \`AGENTS.md\` files for detailed boundary rules.

## Commit Guidelines

- Use \`scripts/committer \"<msg>\" <file...>\` for scoped commits.
- Concise, action-oriented messages (e.g., \`feat: add verbose flag\`).
- Group related changes; avoid bundling unrelated refactors.

## Agent Skills

- Skills live in \`.agents/skills/<name>/SKILL.md\`.
"

make_symlink "CLAUDE.md" "AGENTS.md"

# --- Generate scripts/committer ---

write_file "scripts/committer" '#!/usr/bin/env bash
set -euo pipefail

usage() { printf '\''Usage: %s "commit message" file [file ...]\n'\'' "$(basename "$0")" >&2; exit 2; }
[ "$#" -lt 2 ] && usage

commit_message=$1; shift

for file in "$@"; do
  case "$file" in
    .) printf '\''Error: "." not allowed; list specific paths\n'\'' >&2; exit 1 ;;
    *node_modules*) printf '\''Error: node_modules not allowed: %s\n'\'' "$file" >&2; exit 1 ;;
    *.env|*.env.*) printf '\''Error: env files not allowed: %s\n'\'' "$file" >&2; exit 1 ;;
  esac
done

for file in "$@"; do
  [ -e "$file" ] || { printf '\''Error: file not found: %s\n'\'' "$file" >&2; exit 1; }
done

git restore --staged :/ 2>/dev/null || true
git add --force -- "$@"

if git diff --staged --quiet; then
  printf '\''Warning: no staged changes for: %s\n'\'' "$*" >&2; exit 1
fi

if [ "${FAST_COMMIT:-0}" = "1" ]; then
  FAST_COMMIT=1 git commit -m "$commit_message"
else
  git commit -m "$commit_message"
fi

printf '\''Committed "%s" with %d file(s)\n'\'' "$commit_message" "$#"
'

make_executable "scripts/committer"

# --- Generate git-hooks/pre-commit ---

write_file "git-hooks/pre-commit" '#!/usr/bin/env bash
set -euo pipefail

# Skip heavy checks in fast-commit mode
if [ "${FAST_COMMIT:-0}" = "1" ]; then
  printf "[pre-commit] FAST_COMMIT=1, skipping repo-wide checks\n"
  exit 0
fi

# Get staged files
staged=$(git diff --cached --name-only --diff-filter=ACMR)
[ -z "$staged" ] && exit 0

# TODO: Add your lint/format commands here. Examples:
# Node/TS:  npx eslint $staged
# Python:   ruff check $staged
# Go:       golangci-lint run --new-from-rev=HEAD
# Flutter:  dart analyze

printf "[pre-commit] checks passed\n"
'

make_executable "git-hooks/pre-commit"

# --- Configure git hooks path ---

if [ "$DRY_RUN" = false ] && [ -d ".git" ]; then
  git config core.hooksPath git-hooks 2>/dev/null || true
  printf '[config] git core.hooksPath set to git-hooks\n'
fi

# --- Generate .agents/skills directory with a starter skill ---

write_file ".agents/skills/${PROJECT_NAME}-pr-review/SKILL.md" "---
name: ${PROJECT_NAME}-pr-review
description: Review pull requests for ${PROJECT_NAME} with a focus on code quality, architecture boundary compliance, and test coverage.
---

# PR Review

Use this skill when reviewing pull requests for ${PROJECT_NAME}.

## Prerequisites

- Read \`CLAUDE.md\` for project conventions.
- Read the relevant \`AGENTS.md\` for modules touched by the PR.

## Workflow

1. Check the PR diff for architecture boundary violations.
2. Verify test coverage for changed logic.
3. Check for security issues (hardcoded secrets, SQL injection, XSS).
4. Verify commit messages follow project conventions.
5. Check that no unrelated changes are bundled.

## Verification

- All CI checks pass.
- No new lint warnings introduced.
- Tests cover the changed behavior.

## Common Pitfalls

- Approving PRs that cross module boundaries without updating AGENTS.md.
- Missing test coverage for edge cases.
- Accepting broad \`git add .\` commits that include unrelated files.
"

# --- Generate per-module AGENTS.md stubs ---

if [ -d "$SRC_DIR" ] && [ "$SRC_DIR" != "." ]; then
  for module_dir in "$SRC_DIR"/*/; do
    [ -d "$module_dir" ] || continue
    module_name=$(basename "$module_dir")

    # Only create for directories with 3+ files
    file_count=$(find "$module_dir" -maxdepth 1 -type f | wc -l)
    [ "$file_count" -lt 3 ] && continue

    write_file "${module_dir}AGENTS.md" "# ${module_name} Boundary

This directory owns the ${module_name} module.

## Public Contracts

- Export public API through \`./index.ts\` (or equivalent barrel) only.

## Boundary Rules

- Do not import from sibling modules directly; use their public barrel.
- Keep module-internal types and helpers private.

## Verification

- Run tests: \`${TEST_CMD} ${module_dir}\`
"

    make_symlink "AGENTS.md" "${module_dir}CLAUDE.md"
  done
fi

# --- Summary ---

printf '\n=== Bootstrap Complete ===\n'
printf 'Files created/skipped: %d\n' "$FILES_CREATED"
printf '\nNext steps:\n'
printf '  1. Review and customize CLAUDE.md for your project\n'
printf '  2. Add lint/format commands to git-hooks/pre-commit\n'
printf '  3. Update per-module AGENTS.md files with real boundary rules\n'
printf '  4. Create more skills in .agents/skills/ as needed\n'
if [ "$SKIP_CI" = false ]; then
  printf '  5. Add smart-CI preflight job to your CI pipeline\n'
fi
