# AI-Native Workflow Bootstrap

A project-agnostic toolkit for setting up AI-native development workflows in any codebase. Works with Claude Code, Cursor, Copilot, and other AI coding assistants.

## What it does

Generates a complete 5-layer AI-native development setup:

1. **CLAUDE.md** — Project instructions that AI agents auto-read
2. **scripts/committer** — Safe commit wrapper (prevents `git add .` accidents)
3. **git-hooks/pre-commit** — Pre-commit quality checks
4. **Per-module AGENTS.md** — Scoped boundary rules per module
5. **Agent skills** — Reusable task templates (PR review, deploy, etc.)

## Quick start

### One-liner bootstrap

```bash
cd your-project
bash <(curl -s https://raw.githubusercontent.com/hushwork/ai-native-workflow-bootstrap/main/scripts/bootstrap-ai-workflow.sh)
```

### Or clone and run

```bash
git clone https://github.com/hushwork/ai-native-workflow-bootstrap.git /tmp/ainb
bash /tmp/ainb/scripts/bootstrap-ai-workflow.sh
```

### Or copy as a skill into your project

```bash
mkdir -p .agents/skills
cp -r /path/to/ai-native-workflow-bootstrap .agents/skills/ai-native-workflow-bootstrap
```

Then in Claude Code: "Follow `.agents/skills/ai-native-workflow-bootstrap/SKILL.md` to set up this project."

## Supported stacks

| Stack | Auto-detected by | Source dir |
|-------|-----------------|-----------|
| Node/TypeScript | `package.json` | `src/` |
| Flutter/Dart | `pubspec.yaml` | `lib/` |
| Go | `go.mod` | `.` |
| Python | `pyproject.toml` / `setup.py` | `src/` |
| Rust | `Cargo.toml` | `src/` |

## What gets generated

```
your-project/
  CLAUDE.md              # AI agent instructions (customized to your stack)
  AGENTS.md -> CLAUDE.md # Symlink for other AI tools
  scripts/committer      # Safe commit wrapper
  git-hooks/pre-commit   # Pre-commit hook skeleton
  .agents/skills/        # Agent skill directory
    <project>-pr-review/ # Starter PR review skill
  src/*/AGENTS.md        # Per-module boundary files (for dirs with 3+ files)
```

## Options

```bash
bash bootstrap-ai-workflow.sh --dry-run    # Preview without writing
bash bootstrap-ai-workflow.sh --skip-ci    # Skip CI-related suggestions
```

## The 5-layer model

See [SKILL.md](SKILL.md) for the complete guide, including:

- Decision tree (what to implement based on team size)
- Templates for CLAUDE.md, AGENTS.md, commit wrapper, pre-commit hook, skills
- Frontend-backend collaboration workflow (Swagger/OpenAPI as contract)
- Multi-agent safety rules (parallel AI agents on same codebase)
- Stack-specific notes (NestJS, Flutter, Go, Python, Monorepo)

## License

MIT
