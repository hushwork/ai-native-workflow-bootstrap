# AI-Native Workflow Bootstrap

A Claude Code skill for setting up AI-native development workflows in any codebase.

## Install

```bash
cd your-project
mkdir -p .agents/skills
git clone https://github.com/hushwork/ai-native-workflow-bootstrap.git .agents/skills/ai-native-workflow-bootstrap
```

## Use

### In Claude Code (recommended)

```
> Follow .agents/skills/ai-native-workflow-bootstrap/SKILL.md to set up this project
```

Claude Code reads the skill guide and helps you set up everything step by step.

### Or run the bootstrap script directly

```bash
# Preview what will be generated
.agents/skills/ai-native-workflow-bootstrap/scripts/bootstrap-ai-workflow.sh --dry-run

# Generate files
.agents/skills/ai-native-workflow-bootstrap/scripts/bootstrap-ai-workflow.sh
```

## What it generates

```
your-project/
  CLAUDE.md              # AI agent instructions (customized to your stack)
  AGENTS.md -> CLAUDE.md # Symlink
  scripts/committer      # Safe commit wrapper (prevents git add . accidents)
  git-hooks/pre-commit   # Pre-commit hook skeleton
  .agents/skills/        # Agent skill directory
    <project>-pr-review/ # Starter PR review skill
  src/*/AGENTS.md        # Per-module boundary files
```

## Supported stacks

Auto-detected: Node/TypeScript, Flutter/Dart, Go, Python, Rust.

## The 5-layer model

See [SKILL.md](SKILL.md) for the complete guide:

1. **Code Architecture Constraints** — Module boundaries, import rules
2. **Local Guard Tools** — Commit wrapper, pre-commit hooks
3. **CI/CD Automation** — Smart CI, auto-labeling, stale management
4. **Instruction Hierarchy** — Root CLAUDE.md + per-module AGENTS.md
5. **Agent Skill System** — Reusable task workflows
6. **Frontend-Backend Collaboration** — Auto-generated API spec as contract
7. **Multi-Agent Safety** — Parallel AI agents on same codebase

## Options

```bash
--dry-run    # Preview without writing files
--skip-ci    # Skip CI-related suggestions in output
```

## License

MIT
