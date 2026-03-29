---
name: Validate Code Changes
type: PostToolUse
tools: [Write, Edit]
---

After code has been written or modified, validate all changes against code quality rules.

Run the following evaluation:

1. Execute `git diff` to see all unstaged changes
2. Execute `git diff --staged` to see all staged changes
3. Evaluate ALL changed code (both staged and unstaged) against the rules in the `code-quality:oop` skill
4. Report any violations found, organized by severity (Always Violations first, then Usually Violations)
5. If violations are found, offer to fix them immediately

Focus the evaluation on:
- New code that was just written
- Modified code that was just changed
- Context around changes that may have been affected
