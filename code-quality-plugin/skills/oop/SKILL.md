---
description: Apply OOP and code quality rules for maintainable software
---

# Code Quality Rules

When the user asks you to "check against rules" or similar, apply these object-oriented programming and code quality rules designed to prevent genuine maintainability problems.

**IMPORTANT**: This skill includes detailed reference documents in the `rules/` directory. Consult these for comprehensive guidance:
- `rules/quick-reference.md` - Fast violation lookup
- `rules/severity-guidance.md` - What to fix first
- `rules/README.md` - Overview and philosophy
- Individual rule files for deep context and edge cases

## Quick Decision Process

1. **Start with quick-reference.md** - Use the decision tree for fast violation checks
2. **Check structural foundation first** - Coupling and cohesion (scattered changes), dependency injection (testability)
3. **Check structural organization next** - Abstraction levels (mixing levels), package hierarchy (cycles, vertical deps)
4. **Consider local clarity** - Anonymous code, language separation
5. **Consult detailed rules** - For nuanced situations, read the full rule documents
6. **Consider the Exceptions** - Not everything that looks like a violation is one
7. **Provide context** - Explain WHY something is a problem, not just THAT it violates a rule
8. **Follow priority order** - When rules conflict, higher priority wins (coupling/cohesion beats anonymous code)

## ❌ Always Violations (Fix Immediately)

| Pattern | Example | Why Bad | Fix |
|---------|---------|---------|-----|
| Cyclic dependency | A imports B, B imports C, C imports A | Cannot understand in isolation | Extract shared concept or invert dependency |
| Operators in parameters | `calculate(x + 5, y * 0.08)` | Hides intent | `val total = x + 5; val tax = y * 0.08; calculate(total, tax)` |
| Concrete dependencies | `val db = SqlDatabase()` in class body | Cannot test | `class Service(val db: Database)` |
| Business + I/O mixed | Method validates AND writes to DB | Cannot test logic alone | Separate orchestration from execution |
| Parent package with code | `payments/Utils.kt` + `payments/creditcard/` | Hidden dependencies | Move to `payments/shared/` or down |

## ⚠️ Usually Violations (Fix When Opportune)

| Pattern | When It's A Problem | Test | Fix |
|---------|-------------------|------|-----|
| Large package | 30+ files, unrelated concerns | Do unrelated features touch it? | Split by domain or reason-to-change |
| Long method mixing levels | 50+ lines with orchestration + mechanics | Business change requires understanding details? | Extract implementation to helpers |
| Multi-responsibility class | Changes for multiple unrelated reasons | Appears in commits for different features? | Split by responsibility |
| Scattered changes | Adding feature touches 5+ files | Single feature needs many file edits? | Move related code together |
| Direct event access | `System.err.println()` in business logic | Can you test that events occurred? | Extract to injected interface |

## ✅ Acceptable Patterns (Not Violations)

| Pattern | Example | Why Acceptable |
|---------|---------|---------------|
| Type ops in heterogeneous data | `val cls = constants[i] as ClassConstant` | Domain requires heterogeneity (JVM spec, JSON) |
| Private cohesive helpers | `private fun hexFormat(n: Int)` in Formatter | Serves class's single responsibility |
| Interface convenience | `default fun lookup(i: Int) { return get(i).name() }` | Useful abstraction, reduces duplication |
| api/impl split | `model/api/` and `model/implementation/` | Standard pattern, aids navigation |
| Type dispatch in parsers | `if (value is Map) ... else if (value is List)` | Type checking IS the domain logic |
| Runtime-calculated CSS | `style="width: ${percentage}%"` in progress bar | Value only known at runtime, static styles in CSS |
| Temporary debugging output | `println("DEBUG: processing...")` | Temporary investigation, removed after debugging complete |

## Rule Priority Order

When multiple issues exist or rules conflict, use this priority order:

1. **Coupling and Cohesion** - Foundational principle; changes should be localized
2. **Dependency Injection** - Structurally critical for testing; enables verification
3. **Event Systems** - Explicit event design with testability
4. **Abstraction Levels** - Structural organization of methods and classes
5. **Package Hierarchy** - Package-level architecture (no cycles, no vertical deps)
6. **Anonymous Code** - Local readability; naming intent
7. **Language Separation** - Tooling support; keeps languages in proper contexts
8. **Free Floating Functions** - Discoverability and namespace organization

## The Eight Rules (Summary)

For nuanced situations, consult the detailed rule documents in `rules/`:

### 1. Coupling and Cohesion → `rules/coupling-and-cohesion.md`
Group code that changes together; separate code that changes for different reasons.
- **Problem**: When changes scatter across unrelated files, adding a feature becomes exponential work
- **Test**: Does adding a feature require changing unrelated files?
- **Details**: See the full document for Context and Scale guidance including API/impl splits, size thresholds, module vs package boundaries

### 2. Dependency Injection → `rules/dependency-injection.md`
Depend on interfaces for behavior; inject through composition roots.
- **Problem**: Cannot test code without real infrastructure
- **Test**: Can you test without real I/O?
- **Details**: See the full document for composition roots, when to use interfaces, and legitimate direct dependencies

### 3. Event Systems → `rules/event-systems.md`
Define explicit event interfaces; inject handlers; preserve structured data.
- **Problem**: Global event access (System.out, logger) makes code untestable
- **Test**: Can you verify that important events occurred in tests?
- **Details**: See the full document for event interface patterns and structured data preservation

### 4. Abstraction Levels → `rules/abstraction-levels.md`
Separate orchestration from mechanics; each method operates at a consistent level.
- **Problem**: Methods mixing orchestration with implementation details hide high-level flow
- **Test**: Does understanding the flow require parsing low-level mechanics?
- **Details**: See the full document with extensive examples of acceptable vs problematic mixing

### 5. Package Hierarchy → `rules/package-hierarchy.md`
Organize by domain; no vertical dependencies; no cycles.
- **Problem**: Circular dependencies mean you cannot understand one package without understanding all others
- **Test**: Can you understand packages in isolation?
- **Details**: See the full document for module vs package distinction and acceptable patterns

### 6. Anonymous Code → `rules/anonymous-code.md`
Logic should have meaningful names; no code in parameter lists, no explanatory comments.
- **Problem**: Inline logic without names forces readers to mentally execute mechanics
- **Test**: Do you need comments to explain what code does?
- **Details**: See the full document for acceptable patterns like builder DSLs

### 7. Language Separation → `rules/language-separation.md`
Keep different languages in their own contexts; structured HTML, resource CSS.
- **Problem**: Embedded strings lose syntax highlighting, validation, and refactoring support
- **Test**: Can you edit the language in its native context?
- **Details**: See the full document with examples of runtime-calculated values and acceptable patterns

### 8. Free Floating Functions → `rules/free-floating-functions.md`
Wrap public functions in namespaced containers for discoverability.
- **Problem**: Functions floating at package level without containers makes finding functionality difficult
- **Test**: Can you find functionality without knowing which package to search?
- **Details**: See the full document for language-specific guidance

## Working With Static Analysis Tooling

When static analysis tools detect violations:

### ✅ Correct Response Pattern
1. **Tool reports violation** → Take finding seriously
2. **Evaluate legitimacy** → Is this a real problem or legitimate pattern?
3. **If real problem** → Restructure code to achieve zero violations
4. **If legitimate pattern** → Petition tool maintainers to refine tool (not add to ignore list)

### Key Principles
- **Zero is optimal** - Quality metrics designed so zero is always the goal
- **Clear signal** - 0 → 1 is immediately visible, 15 → 16 is hidden
- **No masking** - New problems obvious when baseline is zero
- **No ignore lists** - Systemic incentive failure

### AI's Role
- ✅ Explain why tool detected violation
- ✅ Evaluate if violation is real problem or legitimate pattern
- ✅ Suggest refactorings to achieve zero violations
- ✅ Help formulate petition for tool maintainers
- ❌ Never add violations to ignore lists
- ❌ Never make subjective exceptions to quality standards

## Additional Resources

- **Test Orchestrator Pattern** → `rules/test-orchestrator-pattern.md`
  - How to hide infrastructure complexity behind domain-focused test APIs
  - Make tests readable, maintainable, and resilient to implementation changes

- **Tooling and AI Integration** → `rules/tooling-and-ai.md`
  - Complete guidance on working with static analysis tools
  - Zero violations philosophy and AI's role

## Remember

- **The goal is maintainable code, not perfect rule compliance**
- **Fix problems, not patterns** - If it works, it might be fine
- **Context matters** - api/impl within a module ≠ across modules
- **Standard patterns are OK** - Don't fight familiar patterns for purity
- **Test pragmatically** - Ask: "Does this cause actual confusion? Do changes scatter? Hard to test?"
- **Respect tooling** - Zero violations is the goal
- **Consult detailed rules** - When situations are nuanced, read the full rule documents in `rules/`

**When in doubt, ask: "Is this making the code genuinely harder to maintain, or just different from the rule?"**

If the code is testable, changeable, and understandable, it's probably fine.

---

**For comprehensive guidance, see:**
- `rules/quick-reference.md` - Fast violation lookup with decision tree
- `rules/severity-guidance.md` - Priority order for fixing violations
- `rules/README.md` - Philosophy and how to use these rules
- Individual rule files for detailed context, rationale, and edge cases
