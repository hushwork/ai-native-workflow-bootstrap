# AI-Native Workflow Bootstrap

A Claude Code skill for setting up AI-native development workflows in any codebase.

## Install

### Project-level (team shares via git)

```bash
cd your-project
git clone https://github.com/hushwork/ai-native-workflow-bootstrap.git .claude/skills/ai-native-workflow-bootstrap
rm -rf .claude/skills/ai-native-workflow-bootstrap/.git
```

Commit `.claude/skills/` to your repo. All teammates using Claude Code will see it.

### Personal-level (available across all your projects)

```bash
git clone https://github.com/hushwork/ai-native-workflow-bootstrap.git ~/.claude/skills/ai-native-workflow-bootstrap
rm -rf ~/.claude/skills/ai-native-workflow-bootstrap/.git
```

## Use

In Claude Code, type:

```
/ai-native-workflow-bootstrap
```

Claude Code will follow the skill guide to set up your project step by step.

Or run the bootstrap script directly for quick setup:

```bash
.claude/skills/ai-native-workflow-bootstrap/scripts/bootstrap-ai-workflow.sh
```

## What it generates

```
your-project/
  CLAUDE.md              # AI agent instructions (customized to your stack)
  AGENTS.md -> CLAUDE.md # Symlink
  scripts/committer      # Safe commit wrapper (prevents git add . accidents)
  git-hooks/pre-commit   # Pre-commit hook skeleton
  .claude/skills/        # Skill directory
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

## How Claude Code skills work

- A skill is a directory with a `SKILL.md` file inside `.claude/skills/`
- `.claude/skills/` = project-level (commit to git, team shares)
- `~/.claude/skills/` = personal-level (all your projects)
- Users invoke with `/skill-name` slash command
- Claude can also auto-invoke based on the skill description
- No registry, no compilation — skills are just markdown instructions

## Options

```bash
--dry-run    # Preview without writing files
--skip-ci    # Skip CI-related suggestions in output
```

## License

MIT
