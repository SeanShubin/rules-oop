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
