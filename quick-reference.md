# Quick Reference: Is This A Violation?

Fast lookup guide for common situations. For details, see the full rules.

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
| Temporary debugging output | `println("DEBUG: processing...")` | Temporary investigation, removed after debugging complete (may need commit for production debugging) |

## Quick Decision Tree

```
Is there a cycle?
  YES → ❌ Fix immediately
  NO ↓

Can you test without real I/O?
  NO → ❌ Fix: inject interfaces
  YES ↓

Are events accessed globally (System.out, logger)?
  YES → ⚠️ Fix: inject event interface
  NO ↓

Is it anonymous code in parameters?
  YES → ❌ Fix: extract to named variables
  NO ↓

Is it a large package (30+ files)?
  YES → Do unrelated features touch it?
    YES → ⚠️ Consider splitting
    NO → ✅ Acceptable
  NO ↓

Is it a long method (50+ lines)?
  YES → Does it mix orchestration + details?
    YES → ⚠️ Consider extracting helpers
    NO → ✅ Acceptable (cohesive complexity)
  NO ↓

Is it type checking/casting?
  YES → Could you eliminate with better types?
    YES → ⚠️ Consider better abstraction
    NO → ✅ Acceptable (inherent to domain)
  NO ↓

Does it follow a standard pattern?
  YES → Is it causing actual problems?
    YES → Consider alternatives
    NO → ✅ Acceptable
  NO ↓

✅ Probably fine - focus on actual problems
```

## Module vs Package Boundaries

| Concern | Module Boundaries | Package Boundaries (within module) |
|---------|------------------|----------------------------------|
| Purpose | Release/versioning units (REP) | Organizational navigation |
| Cycles | ❌ Never allowed (High Severity) | ❌ Never allowed (Medium Severity) |
| Vertical deps | ❌ Never allowed (Medium Severity) | ❌ Never allowed (Medium Severity) |
| Domain-first | Strongly enforced | Encouraged, patterns acceptable |
| Standard patterns | Acceptable (e.g. api/impl modules) | Acceptable (e.g. api/impl packages) |
| Ownership | Module owns package subtree | Packages owned by their module |
| Impact of violations | Affects external consumers, versioning | Affects internal navigation only |
| Test | "Does this force unwanted dependencies on consumers?" (CRP) | "Does this help navigation?" |

**Key insight:** Module boundaries are architectural (release units). Package boundaries within modules are organizational (navigation aids). Both matter, but module violations have broader impact.

## Common False Alarms

These look like violations but usually aren't:

### ✅ "Abstraction mixing" that's actually fine
```java
// This is FINE - private helper serving formatter
class ReportFormatter {
    String format(Report r) { return formatHeader(r) + formatBody(r); }
    private String formatHeader(Report r) { return "=".repeat(50) + r.title(); }
}
```

### ✅ "Coupling" that's actually fine
```kotlin
// This is FINE - api/impl within one module
domain/
  model/
    api/           // interfaces
    implementation/ // implementations
```

### ✅ "Type operations" that are necessary
```java
// This is FINE - JSON inherently requires type dispatch
class JsonSerializer {
    String serialize(Object value) {
        if (value instanceof String) return serializeString((String) value);
        if (value instanceof Map) return serializeMap((Map) value);
        // ... type dispatch is the domain logic
    }
}
```

### ✅ "Long method" that's cohesive
```kotlin
// This is FINE - all parsing logic at one level
private fun parseTimeString(input: String): Duration {
    val parts = input.split(":")
    val hours = parts[0].toInt()
    val minutes = parts[1].toInt()
    val seconds = parts[2].toInt()
    return Duration.ofHours(hours).plusMinutes(minutes).plusSeconds(seconds)
    // 30 lines of parsing is fine if it's all at one level
}
```

## When To Ask For Clarification

If you're unsure, ask these questions:

1. **"Does this cause actual confusion?"** - If no, probably fine
2. **"Can you test it in isolation?"** - If yes, dependency injection is working
3. **"Do changes scatter across many files?"** - If no, cohesion is fine
4. **"Would refactoring make it clearer?"** - If no, leave it alone

## Priority Order

When multiple issues exist, fix in this order (based on structural criticality):

1. 🔴 **Coupling and Cohesion** - Changes should be localized, foundational for maintainability
2. 🔴 **Dependency Injection** - Cannot verify correctness without testability
3. 🟡 **Event Systems** - Explicit event design with testability; application of dependency injection for observability
4. 🟡 **Abstraction Levels** - Structural organization affects how you change code
5. 🟡 **Package Hierarchy (including cycles)** - Package-level architecture and dependencies
6. 🟡 **Anonymous code** - Local readability, hides intent
7. 🟢 **Language Separation** - Tooling support, only when mixing languages
8. 🟢 **Free Floating Functions** - Discoverability, lowest priority

## Working With Static Analysis Tooling

When static analysis tools detect violations:

### ✅ Correct Response Pattern
1. **Tool reports violation** → Take finding seriously
2. **Evaluate legitimacy** → Is this a real problem or legitimate pattern?
3. **If real problem** → Restructure code to achieve zero
4. **If legitimate pattern** → Petition tool maintainers to refine tool (not add to ignore list)

### ❌ Anti-Patterns
- Adding violations to ignore lists → systemic incentive failure
- "This violation is fine, leave it" → signal degradation
- Working around tool without addressing root issue → hiding problems

### AI's Role With Tooling
**AI can:**
- ✅ Explain why tool detected violation
- ✅ Evaluate if violation is real problem or legitimate pattern
- ✅ Suggest refactorings to achieve zero violations
- ✅ Help formulate petition for tool maintainers
- ✅ Propose mechanical detection strategies for legitimate patterns
- ✅ Challenge tool findings if they seem unreasonable

**AI cannot:**
- ❌ Add violations to ignore lists
- ❌ Override tool maintainer decisions
- ❌ Make subjective exceptions to quality standards
- ❌ Tell developers "this violation is acceptable, leave it"

### Zero Violations Philosophy
- **Zero is optimal** - Quality metrics designed so zero is always the goal
- **Clear signal** - 0 → 1 is immediately visible, 15 → 16 is hidden
- **No masking** - New problems obvious when baseline is zero
- **Incentive alignment** - Only path forward is fix problem or refine tool

See **[Tooling and AI Integration](tooling-and-ai.md)** for complete details.

## Remember

- **Fix problems, not patterns** - If it works, it might be fine
- **Context matters** - api/impl within a module ≠ across modules
- **Standard patterns are OK** - Don't fight familiar patterns for purity
- **Test pragmatically** - Actual confusion? Scattered changes? Hard to test?
- **Respect tooling** - Zero violations is the goal, not subjective exceptions

**The goal is maintainable code, not perfect compliance.**
