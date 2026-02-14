# Using These Rules with Claude Code

To ensure Claude Code consistently applies these OOP rules when generating code in your projects, set up project memory.

## Per-Project Setup

Each OOP project should have its own `.claude/CLAUDE.md` that references these rules.

### 1. Symlink the rules into your project

```bash
cd /path/to/your/project
mkdir -p .claude/rules
ln -s /path/to/rules-oop .claude/rules/oop
```

Replace `/path/to/rules-oop` with the actual path to where you cloned this rules repository.

### 2. Create `.claude/CLAUDE.md` in your project root

```markdown
# Code Quality Standards

See @rules/oop/README.md for complete guidelines.

When generating or reviewing code, follow these rules in priority order:
1. @rules/oop/coupling-and-cohesion.md
2. @rules/oop/dependency-injection.md
3. @rules/oop/event-systems.md
4. @rules/oop/abstraction-levels.md
5. @rules/oop/package-hierarchy.md
6. @rules/oop/anonymous-code.md
7. @rules/oop/language-separation.md
8. @rules/oop/free-floating-functions.md

Consult @rules/oop/severity-guidance.md for severity calibration.
Consult @rules/oop/quick-reference.md for fast violation lookup.

## Testing Practice

Follow @rules/oop/test-orchestrator-pattern.md for test design.

## Tooling

Follow @rules/oop/tooling-and-ai.md for working with static analysis and AI integration.
```

### 3. Recommended `.gitignore` entry

```gitignore
# Ignore symlinked rules (each developer points to their own location)
.claude/rules/
```

**Check in to version control:**
- `.claude/CLAUDE.md` - The reference to rules (everyone needs this)

**Don't check in:**
- `.claude/rules/oop/` - The symlink (path is developer-specific)

## Global Setup (Alternative)

If you prefer global symlinks (set once, available to all projects), add to `~/.claude/rules/`:

```bash
mkdir -p ~/.claude/rules
ln -s /path/to/rules-oop ~/.claude/rules/oop
```

Then project `.claude/CLAUDE.md` files can reference `@rules/oop/` without per-project symlinks.

## Verification

After setup, verify Claude has loaded your rules:

```bash
claude /memory
```

This shows which memory files are loaded and in what order.

## How It Works

- `.claude/CLAUDE.md` is automatically loaded at the start of every session
- The `@rules/` references load those rule files into context
- Rules persist across sessions - no need to remind Claude
- Rules are checked into version control, so your team benefits too

## Documentation

For more details, see [Claude Code Memory Documentation](https://code.claude.com/docs/en/memory.md).
