# Creating a Claude Code Plugin from this Repository

This guide shows how to bundle the rules-oop repository as a Claude Code plugin, eliminating the need for symlinks.

**Note**: This repository contains both the source rules (at root level) and the plugin distribution (in `code-quality-plugin/`). The marketplace configuration is at `.claude-plugin/marketplace.json` at the repository root.

**Plugin Structure**: The plugin `code-quality` contains multiple skills:
- `oop` - Object-oriented programming rules
- `ecs` - Entity component system rules (to be added)

## Prerequisites

- Claude Code CLI installed (version 2.1.80 or later)

## Process Overview

1. Create the plugin directory structure
2. Copy the detailed rules into the plugin
3. Create a skill that references the rules
4. Create the plugin manifest
5. Create the marketplace configuration at repository root
6. Validate and test
7. Set up the sync script (optional but recommended)
8. Push to GitHub for distribution

## Step 1: Create the Plugin Structure

Create the directory structure for the plugin:

```bash
mkdir -p code-quality-plugin/.claude-plugin
mkdir -p code-quality-plugin/skills/oop
mkdir -p code-quality-plugin/rules
```

Note: You can add more skills later (e.g., `skills/ecs/` for entity component system rules).

## Step 2: Copy the Detailed Rules

Copy all rule files into the plugin so they're embedded and available:

```bash
cp coupling-and-cohesion.md \
   dependency-injection.md \
   event-systems.md \
   abstraction-levels.md \
   package-hierarchy.md \
   anonymous-code.md \
   language-separation.md \
   free-floating-functions.md \
   quick-reference.md \
   severity-guidance.md \
   tooling-and-ai.md \
   test-orchestrator-pattern.md \
   README.md \
   code-quality-plugin/rules/
```

This embeds ~215KB of detailed guidance in the plugin, including:
- All 8 core rule documents with full context, rationale, and edge cases
- Quick reference with decision tree
- Severity guidance for prioritizing fixes
- Tooling and AI integration guidance
- Test orchestrator pattern documentation

## Step 3: Create the Skill

A skill is simply a markdown file with YAML frontmatter. Create `code-quality-plugin/skills/oop/SKILL.md` that provides quick reference and points to the detailed rules:

The skill file should:
- Provide quick violation lookup tables
- Reference the detailed rule files in `rules/` directory
- Include the decision tree for fast checks
- Point to specific files for nuanced situations

See the existing `SKILL.md` for the current structure.

## Step 4: Create the Plugin Manifest

Create `code-quality-plugin/.claude-plugin/plugin.json`:

```json
{
  "name": "code-quality",
  "description": "Code quality rules for maintainable software (OOP, ECS, and more)",
  "version": "1.0.0",
  "author": {
    "name": "Sean Shubin"
  },
  "license": "MIT",
  "keywords": ["code-quality", "oop", "ecs", "maintainability", "testing", "architecture"]
}
```

## Step 5: Create the Marketplace Configuration

Create `.claude-plugin/marketplace.json` at the repository root:

```bash
mkdir -p .claude-plugin
```

Create `.claude-plugin/marketplace.json`:

```json
{
  "name": "seanshubin",
  "owner": {
    "name": "Sean Shubin"
  },
  "metadata": {
    "description": "Sean Shubin's code quality rules (OOP, ECS, and more)"
  },
  "plugins": [
    {
      "name": "code-quality",
      "source": "./code-quality-plugin",
      "description": "Code quality rules for maintainable software (OOP, ECS, and more)",
      "version": "1.0.0"
    }
  ]
}
```

This makes the entire repository a marketplace, with the plugin as a subdirectory.

## Step 6: Validate and Test

Validate everything:

```bash
# Validate plugin
cd code-quality-plugin
claude plugin validate .

# Validate marketplace
cd ..
claude plugin validate .
```

Test locally:

```bash
# Add the marketplace (use your local path)
claude plugin marketplace add /Users/seashubi/github.com/SeanShubin/rules-oop

# Install the plugin
claude plugin install code-quality@seanshubin
```

Try using the skill in a conversation by asking Claude to "check against code-quality:oop rules".

## Step 7: Set Up the Sync Script (Recommended)

Create a script to automate syncing rule updates to the plugin. This ensures the plugin stays in sync with your rule files:

Create `sync-plugin.sh`:

```bash
#!/bin/bash
# sync-plugin.sh
# Synchronizes rule files to plugin

set -e

REPO_ROOT="/Users/seashubi/github.com/SeanShubin/rules-oop"
cd "$REPO_ROOT"

echo "Syncing rule files to plugin..."
cp coupling-and-cohesion.md \
   dependency-injection.md \
   event-systems.md \
   abstraction-levels.md \
   package-hierarchy.md \
   anonymous-code.md \
   language-separation.md \
   free-floating-functions.md \
   quick-reference.md \
   severity-guidance.md \
   tooling-and-ai.md \
   test-orchestrator-pattern.md \
   README.md \
   code-quality-plugin/rules/

echo "Validating plugin..."
cd code-quality-plugin
claude plugin validate .

echo "Done! Plugin is synchronized."
```

Make it executable:

```bash
chmod +x sync-plugin.sh
```

**When to use the sync script:**
- After editing any rule file
- Before committing changes
- Before pushing to GitHub

The script handles:
- Copying all rule files to the plugin
- Validating the plugin structure
- Checking if installed plugin matches source
- Telling you if reinstall is needed

**Additional scripts:**

`verify-plugin.sh` - Check only (no changes):
```bash
./verify-plugin.sh
```

This shows differences between installed plugin and source without syncing. Safe for CI/CD pipelines.

`install-plugin-local.sh` - Install from local:
```bash
./install-plugin-local.sh
```

Installs plugin from local directory, checks if out of date first, then verifies. Perfect for daily workflow after syncing.

**Which script to use:**
- **Daily development**: `./sync-plugin.sh && ./install-plugin-local.sh`
- **Just checking status**: `./verify-plugin.sh` (read-only)
- **Before releasing**: `./install-plugin-github.sh` (test what users will get)
- **CI/CD validation**: `./verify-plugin.sh` (exit code indicates status)

## Step 8: Push to GitHub

Your repository is now a complete marketplace. Simply push to GitHub:

```bash
git add .
git commit -m "Add OOP rules plugin"
git push
```

Users can then install with:

```bash
# Add your repository as a marketplace
claude plugin marketplace add SeanShubin/rules-oop

# Install the plugin
claude plugin install code-quality@seanshubin
```

**Using the skills:**
- OOP rules: Ask Claude to "check against code-quality:oop rules"
- ECS rules: Ask Claude to "check against code-quality:ecs rules" (once added)

### Benefits of Single Repository

✅ **Single source of truth** - Rules and plugin in one place
✅ **Easier maintenance** - One repo to manage, one place to push
✅ **Better discoverability** - Users find rules AND plugin at same GitHub URL
✅ **Simpler workflow** - Edit rules at root, sync to plugin, push once

## Using the Plugin

Once installed, the plugin will:
- Automatically load the rules into Claude Code sessions
- Make rules available to all projects without symlinks
- Provide consistent rule application across your codebase

Enable/disable as needed:
```bash
# Enable the plugin
claude plugin enable code-quality

# Disable the plugin
claude plugin disable code-quality

# Check status
claude plugin list
```

**Skill invocation:**
- `code-quality:oop` - Check code against OOP rules
- `code-quality:ecs` - Check code against ECS rules (once added)

## Benefits Over Symlinks

- **No per-project setup**: Install once, available everywhere
- **Version management**: Update plugin to get rule updates
- **Team distribution**: Share plugin package or marketplace link
- **No .gitignore needed**: No symlinks to exclude from version control
- **Consistent loading**: Plugin system ensures proper loading order

## Maintenance Workflow

After initial setup, use this workflow to update the plugin:

### Option A: Full Automation (Recommended)

1. **Edit rules** in the main repository (e.g., `coupling-and-cohesion.md`)
2. **Sync and install**: `./sync-plugin.sh && ./install-plugin-local.sh`
3. **Commit changes** to git
4. **Push to GitHub** - users get updates on next marketplace refresh

### Option B: Manual Control

1. **Edit rules** in the main repository (e.g., `coupling-and-cohesion.md`)
2. **Run sync script**: `./sync-plugin.sh`
3. **Review differences** if shown
4. **Install if needed**: `claude plugin install code-quality@seanshubin`
5. **Verify**: `./verify-plugin.sh`
6. **Commit changes** to git
7. **Push to GitHub**

### Option C: Full Release Workflow (Recommended for Teams)

1. **Make changes** locally
2. **Sync to plugin**: `./sync-plugin.sh`
3. **Test locally**: `./install-plugin-local.sh`
4. **Commit**: `git add . && git commit -m "Update rules"`
5. **Test GitHub before push**: `./install-plugin-github.sh` (should differ)
6. **Push**: `git push`
7. **Verify release**: `./install-plugin-github.sh` (should match)
8. **Restore local dev**: `./install-plugin-local.sh`

### Daily Check

Just run:
```bash
./install-plugin-local.sh
```

This ensures your installed plugin is always up to date with your source.

### Testing GitHub Distribution

Before releasing to your team, verify what they'll actually get:

```bash
./install-plugin-github.sh
```

This script:
1. **Warns about uncommitted/unpushed changes** - GitHub won't have them
2. **Removes local marketplace** - Temporarily switches to GitHub
3. **Installs from GitHub** - Exactly like your users will
4. **Compares to local source** - Shows any differences
5. **Restores local marketplace** - Back to development mode

**Example output:**
```
⚠️  WARNING: You have unpushed commits
The GitHub version will not include these commits

  c1d503b Update coupling rule (not pushed)

Continue anyway? (y/n)
```

**Use this before releases:**
```bash
# 1. Make your changes
vim coupling-and-cohesion.md
./sync-plugin.sh

# 2. Test locally
./install-plugin-local.sh

# 3. Commit (but don't push yet)
git add . && git commit -m "Update coupling rule"

# 4. Test what's currently on GitHub
./install-plugin-github.sh
# Should show differences (your new commit isn't pushed)

# 5. Push to release
git push

# 6. Verify users will get your changes
./install-plugin-github.sh
# Should now match!
```

## Quick Start Summary

For those who already have the structure:

```bash
# Edit rules
vim coupling-and-cohesion.md

# Sync and auto-install
./sync-plugin.sh && ./install-plugin-local.sh

# Push to GitHub for distribution
git add . && git commit -m "Update rules" && git push
```

**Four helper scripts:**

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `sync-plugin.sh` | Sync rules to plugin, check status | After editing rules |
| `verify-plugin.sh` | Check only, no changes | Just checking status, CI/CD |
| `install-plugin-local.sh` | Install from local directory | Daily workflow, after syncing |
| `install-plugin-github.sh` | Install from GitHub | Before releasing, verify what users get |

Users install with:

```bash
claude plugin marketplace add SeanShubin/rules-oop
claude plugin install code-quality@seanshubin
```

## Notes

- **Keep the original repository for maintaining the rules** - The plugin is a distribution format, not the source of truth
- **Use the sync script** - Run `./sync-plugin.sh` after editing any rule file to keep plugin in sync
- **Version management** - Update plugin version in `plugin.json` when making significant changes
- **Semantic versioning** - Consider semver for plugin releases (1.0.0 → 1.1.0 for new rules, 1.0.0 → 1.0.1 for clarifications)
- **Skills are just markdown** - No special tools required, just markdown files with YAML frontmatter
- **Detailed rules embedded** - All ~215KB of rule documentation is included in the plugin for comprehensive guidance
