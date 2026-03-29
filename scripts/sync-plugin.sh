#!/bin/bash
# sync-plugin.sh
# Synchronizes rule files to plugin and checks if reinstall is needed

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
INSTALLED="$HOME/.claude/plugins/cache/seanshubin/code-quality/1.0.0"

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

echo "Syncing hooks..."
# Hooks directory already exists in plugin, no copy needed

echo "Validating plugin..."
cd code-quality-plugin
claude plugin validate .

echo ""
echo "✅ Plugin synchronized and validated"
echo ""

# Check if plugin is installed and compare
if [ -d "$INSTALLED" ]; then
    echo "Checking installed plugin..."
    cd "$REPO_ROOT"

    # Compare directories, excluding common non-essential files
    if diff -r "$INSTALLED" code-quality-plugin/ \
        --exclude=".git" \
        --exclude=".DS_Store" \
        --exclude="*.swp" \
        > /dev/null 2>&1; then
        echo "✅ Installed plugin matches source - no reinstall needed"
    else
        echo "⚠️  Installed plugin differs from source"
        echo ""
        echo "Differences found. To update installed plugin:"
        echo "  claude plugin install code-quality@seanshubin"
        echo ""
        echo "Or uninstall and reinstall:"
        echo "  claude plugin uninstall code-quality@seanshubin"
        echo "  claude plugin marketplace add $REPO_ROOT"
        echo "  claude plugin install code-quality@seanshubin"
    fi
else
    echo "ℹ️  Plugin not yet installed"
    echo ""
    echo "To install:"
    echo "  claude plugin marketplace add $REPO_ROOT"
    echo "  claude plugin install code-quality@seanshubin"
fi
