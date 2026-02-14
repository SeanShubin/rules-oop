# Code Quality Rules

This directory contains architectural and code quality rules designed to prevent genuine maintainability problems without creating false alarms for reasonable design choices.

**Using with Claude Code?** See [claude-code-setup.md](claude-code-setup.md) for instructions on making these rules persist across sessions.

## The Rules

1. **[Coupling and Cohesion](coupling-and-cohesion.md)** - Group code that changes together; separate code that changes for different reasons
2. **[Dependency Injection](dependency-injection.md)** - Depend on interfaces for behavior; inject through composition roots
3. **[Event Systems](event-systems.md)** - Define explicit event interfaces; inject handlers; preserve structured data
4. **[Abstraction Levels](abstraction-levels.md)** - Separate orchestration from mechanics; each method operates at a consistent level
5. **[Package Hierarchy](package-hierarchy.md)** - Organize by domain; no vertical dependencies; no cycles
6. **[Anonymous Code](anonymous-code.md)** - Logic should have meaningful names; no code in parameter lists, no explanatory comments
7. **[Language Separation](language-separation.md)** - Keep different languages in their own contexts; structured HTML, resource CSS
8. **[Free Floating Functions](free-floating-functions.md)** - Wrap public functions in namespaced containers for discoverability

## Testing Practice

**[Test Orchestrator Pattern](test-orchestrator-pattern.md)** - Hide infrastructure complexity behind a domain-focused test API; make tests readable, maintainable, and resilient to implementation changes

## Tooling and Process

**[Tooling and AI Integration](tooling-and-ai.md)** - Static analysis provides objective measurement; AI assists understanding; zero violations is optimal; no ignore lists

## Start Here: [Severity Guidance](severity-guidance.md)

Before diving into individual rules, read the **Severity Guidance** to understand:
- Which violations must be fixed immediately (cyclic dependencies, untestable code)
- Which violations should be fixed when opportune (large packages, long methods)
- Which patterns are acceptable in context (type operations, private helpers, standard patterns)
- Practical tests to determine if something is actually a problem

The severity guidance helps you distinguish between genuine maintainability issues and acceptable design choices.

## Philosophy

These rules target **real maintainability problems**, not aesthetic preferences.

### Problems That Multiply

When changes scatter across unrelated files, adding a feature becomes exponential work - you must understand and coordinate changes in multiple places that shouldn't need to know about each other. When code that changes together is separated, a single logical change requires hunting through packages and classes. (Coupling and Cohesion)

When you cannot test code without real infrastructure, you cannot verify correctness during development. When business logic and infrastructure are mixed, you cannot change data structures without understanding networking code, or vice versa. (Dependency Injection)

When events are accessed globally through singletons, code becomes untestable and you cannot verify that important boundary interactions occurred. When event data is formatted into strings at the source, structured information is lost and cannot be queried or analyzed effectively. (Event Systems)

### Problems That Hide Structure

When methods mix orchestration with implementation details, understanding the high-level flow requires parsing low-level mechanics. When high-level code knows about low-level details, changing how something works requires changing what uses it. (Abstraction Levels)

When packages have circular dependencies, you cannot understand one package without understanding all others in the cycle - there is no place to start. When parent packages depend on child packages, the hierarchy inverts and navigation becomes confusing. (Package Hierarchy)

### Problems That Hide Intent

When logic appears inline without names, readers must mentally execute mechanics to infer purpose. When code needs comments to explain what it does, the code structure isn't communicating intent. (Anonymous Code)

When HTML or CSS are embedded as string literals, you lose syntax highlighting, validation, and refactoring support from your tools. The languages cannot be edited in their native contexts. (Language Separation)

### Problems That Slow Discovery

When public functions float at package level without containers, finding functionality requires knowing which package to search. Namespaced containers provide logical groupings. (Free Floating Functions)

### Patterns That Are Fine

Some patterns look like violations but serve legitimate purposes:
- **Type operations** when heterogeneity is inherent to the domain (JVM spec, JSON parsers)
- **Private helpers** that serve the class's single responsibility cohesively
- **Standard patterns** like api/impl splits when established and working
- **Package organization** flexibility within modules vs across module boundaries
- **Runtime-calculated values** like `style="width: ${percent}%"` for progress bars when values are only known at runtime

## How to Use These Rules

### For Developers

1. **Read [Severity Guidance](severity-guidance.md) first** to calibrate your judgment
2. **Consult specific rules** when you encounter situations they address
3. **Use practical tests** before refactoring:
   - Does this cause actual confusion?
   - Do changes scatter across unrelated files?
   - Can you test it in isolation?
   - Would refactoring make it clearer or just move complexity?

### For Code Reviewers

1. **Focus on highest-priority violations** - Scattered changes, poor cohesion, untestable code
2. **Check structural issues next** - Methods mixing levels, cyclic dependencies, vertical dependencies
3. **Consider context for local issues** - Anonymous code, language mixing - do they actually cause problems?
4. **Don't flag acceptable patterns** - Type operations in heterogeneous data, private cohesive helpers, standard patterns, runtime-calculated CSS
5. **Ask practical questions** - "Does this make testing difficult?" "Do changes scatter?" not "Does this perfectly follow the rule?"

### For AI Assistants

When checking code against these rules:

1. **Start with [Severity Guidance](severity-guidance.md)** to understand what matters most
2. **Check structural foundation first** - Coupling and cohesion (scattered changes), dependency injection (testability)
3. **Check structural organization next** - Abstraction levels (mixing levels), package hierarchy (cycles, vertical deps)
4. **Consider local clarity** - Anonymous code, language separation
5. **Consider the Exceptions sections** in each rule - Not everything that looks like a violation is one
6. **Look at the Examples** in abstraction-levels.md and language-separation.md to see ❌ violations vs ✅ acceptable patterns
7. **Provide context** - Explain WHY something is a problem, not just THAT it violates a rule
8. **Follow priority order** - When rules conflict, higher priority wins (coupling/cohesion beats anonymous code)
9. **Respect [Tooling and AI Integration](tooling-and-ai.md)** - When static analysis detects violations, take findings seriously, help achieve zero violations, never suggest ignore lists

## Key Distinctions

### Module vs Package Boundaries
- **Module boundaries** are architectural - dependencies create deployment and compilation constraints
- **Package boundaries** within a module are organizational - they aid navigation but are more flexible
- Apply rules more strictly across modules than within them

### Patterns vs Principles
- **Patterns** (api/impl, interface/implementation) are acceptable when established and working
- **Principles** (no cycles, no vertical deps) apply universally
- Don't fight familiar patterns for theoretical purity

### Complexity That Can Be Eliminated vs Inherent Complexity
- **Eliminable**: Type checking because you used `Map<String, Object>` instead of proper types
- **Inherent**: Type checking in a JSON parser - the domain requires runtime dispatch
- Extract eliminable complexity; accept inherent complexity with good naming

### Private Helpers vs Public Utilities
- **Private helpers** serving the class's single responsibility are fine
- **Public utilities** need clear homes and responsibilities
- Don't extract private helpers just to hit a method length target

## When Rules Conflict

Sometimes rules appear to conflict. Use this priority order based on structural criticality and principle generality:

1. **Coupling and Cohesion** - Foundational principle affecting all scales; changes should be localized
2. **Dependency Injection** - Structurally critical for testing architecture; enables verification
3. **Event Systems** - Explicit event design with testability; specific application of dependency injection for observability
4. **Abstraction Levels** - Structural organization of methods and classes; separates concerns by detail level
5. **Package Hierarchy** - Package-level architecture; applies coupling principles with specific constraints (no cycles, no vertical deps)
6. **Anonymous Code** - Local readability; naming intent within expressions and statements
7. **Language Separation** - Tooling support and organization; keeps languages in proper contexts
8. **Free Floating Functions** - Discoverability and namespace organization

If following one rule would violate a higher-priority rule, follow the higher-priority rule.

**Rationale**: Structural impact determines priority. Rules affecting architecture and how code changes (coupling, testability, organization) take precedence over local readability concerns. More general principles (coupling and cohesion applies everywhere) rank higher than specific manifestations (package hierarchy applies it at package level).

## Evolution and Feedback

These rules reflect current understanding of maintainable code. They should evolve based on:
- **Actual problems encountered** in codebases
- **False alarms** that waste developer time
- **New patterns and practices** that emerge
- **Context-specific needs** of different domains

If a rule consistently creates false alarms or conflicts with practical reality, the rule should be refined, not the code forced to comply.

## Summary

**The goal is maintainable code, not perfect rule compliance.**

Rules should help you:
- ✅ Prevent genuine problems (cycles, untestable code, scattered changes)
- ✅ Make informed trade-offs (extraction vs inline, organization patterns)
- ✅ Focus effort on high-impact improvements

Rules should not:
- ❌ Create false alarms for reasonable design choices
- ❌ Force refactoring that moves complexity without reducing it
- ❌ Prioritize theoretical purity over practical clarity

When in doubt, ask: **"Is this making the code genuinely harder to maintain, or just different from the rule?"**

If the code is testable, changeable, and understandable, it's probably fine.
