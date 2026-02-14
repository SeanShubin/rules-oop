# Package Hierarchy

## Concept
Package hierarchies organize code through namespacing and grouping. Without structure, parent packages become dumping grounds where developers place shared code without thoughtful categorization. The distinction between organizing packages (empty containers) and code packages (leaf nodes with actual code) forces explicit naming decisions and prevents vertical coupling that obscures true dependencies.

## Module and Package Correspondence

Modules and packages are connected through ownership: each module owns a package subtree.

- **Module owns package subtree**: The `infrastructure` module owns `com.company.infrastructure` and all packages under it (`infrastructure.time`, `infrastructure.collections`, etc.)
- **Module name matches root package**: Module `classfile` owns `com.company.classfile.*`. This makes ownership immediately obvious from package names.
- **Packages don't span modules**: All classes in `com.company.model.api` must live in the same module. You cannot split a package across modules.
- **Root package can be organizing or code**: Small/focused modules may have code directly in root package. Complex modules should use root as organizing container with code in subpackages.

This correspondence prevents organizational chaos: looking at a package name tells you which module owns it, and which release/version it belongs to.

**Connection to Reuse-Release Equivalence Principle (REP)**: Module boundaries are release boundaries. When you version the `model` module, you're versioning everything under `com.company.model.*`. Consumers take the entire subtree as a unit. This is why packages within a module have more organizational flexibility than packages across modules - within a module, they're part of the same release; across modules, they're separate versioned components.

## Implementation
- Two package types:
    - Organizing packages: contain only subpackages, zero code
    - Code packages: contain only code, zero subpackages
- Grouping priority: business domain first, functional area only when necessary
- Default to flat: keep hierarchy shallow until organizational needs require depth
- All parent packages must be organizing packages
- No vertical dependencies:
    - ancestors must not depend on descendants
    - descendants must not depend on ancestors
- Shared code between siblings goes in explicitly-named sibling packages (e.g., `.shared`, `.common`, `.core`)
- Horizontal dependencies allowed:
    - between siblings
    - to descendants of siblings
    - to ancestors of siblings (excluding common ancestors)
- Split packages with multiple responsibilities
- No cyclic dependencies
- Cross-cutting concerns:
    - no special privileges
    - dependency inject them like any other concern
    - example: treat logging as events with injected handlers

## Context and Scope

The strictness of this rule depends on the architectural boundaries:

**Across module boundaries (STRICT):**
- Modules are release units with independent versioning (per REP - Reuse-Release Equivalence Principle)
- Module boundaries create deployment and compilation constraints
- Dependencies between modules affect what consumers must take (per CRP - Common Reuse Principle)
- No cycles between modules (always enforced)
- No vertical dependencies between modules (always enforced)
- Organize by domain, not technical layers (strongly encouraged)

**Within a module (FLEXIBLE):**
- Packages are organizational aids within a single release unit
- Standard patterns (api/impl, interface/implementation) are acceptable
- Package structure should aid navigation and prevent confusion
- No cycles within module (always enforced via static analysis)
- No parent-child dependencies (always enforced via static analysis)
- Domain-first organization encouraged but not mandatory if patterns are clear

**The test:** Between modules, ask "Does this dependency force consumers to take unwanted code?" (Common Reuse Principle). Within modules, ask "Does this organization help developers find what they need?"

**When to be strict:** Enforce rigorously when:
- Packages represent different deployment units or libraries
- Packages cross team boundaries (team A owns `payments/`, team B owns `orders/`)
- Packages represent architectural layers that should be independently deployable
- Cycles or vertical dependencies exist (always high severity regardless of scope)

**When to be flexible:** Within a cohesive module owned by one team:
- Standard organizational patterns (api/impl, interface/implementation) are acceptable
- Package structure that aids navigation is more important than perfect domain alignment
- Consistency with existing patterns has value
- If no cycles or vertical dependencies exist, the package structure is working

**Module boundaries vs. package boundaries:** A dependency between two packages in the same module (`domain.model.api` → `domain.classfile.structure`) is fundamentally different from a dependency between modules (`domain` module → `infrastructure` module). The former is organizational; the latter is architectural.

## Rationale
"Won't this force awkward sibling relationships?" No. Requiring shared utilities to live in explicitly-named siblings (like `payments.shared`) is more honest than hiding them in parent packages. It forces you to acknowledge when code is truly shared and name it accordingly, rather than lazily dumping it in `payments` because it's convenient.

"Don't child packages naturally depend on parent utilities?" This intuition leads to parent packages becoming catch-alls. When `payments.creditcard` needs utilities, creating `payments.shared` requires a conscious decision about what truly spans multiple payment types versus what belongs specifically to credit cards. This friction is valuable.

"What about duplication?" Sibling packages eliminate duplication concerns. If multiple packages need the same code, it belongs in an explicitly-named sibling, not duplicated and not hidden in a parent.

"What about truly foundational types that everything needs?" Cross-cutting concerns don't get special treatment. Use dependency injection to push these concerns to boundaries. For unavoidable shared types, create an explicitly-named package at the appropriate hierarchy level (e.g., `com.company.core.types` as a sibling to major modules).

"Why prohibit both directions of vertical dependency?" Each direction indicates a different problem. Parents depending on children suggests misplaced code that should be pushed down. Children depending on parents suggests shared code that should be pulled out to a named sibling. Both indicate organizational debt worth addressing.

"What about the api/impl pattern?" This is a special case. When `model.api` and `model.implementation` exist as siblings under `model`, this is acceptable. They're not parent-child; they're siblings with a clear relationship. The `model` parent is an organizing package (no code), and the two siblings represent the standard interface/implementation split. This is different from code living directly in the parent package.

"When do cycles matter vs. not matter?" Cycles ALWAYS matter. They indicate tight coupling that makes code hard to understand and change. Even within a single module, cycles should be eliminated. This is non-negotiable. However, the absence of cycles within a module doesn't mean package organization must be perfect - it means dependencies are at least flowing in consistent directions.

## Pushback
This rule assumes that explicit is better than convenient, and that useful friction prevents organizational decay. It values forcing conscious decisions about code placement over allowing developers to quickly dump shared code in parent packages. It assumes that navigating dependencies is important enough to enforce through structure, and that the cost of creating explicitly-named siblings is worth the benefit of honest dependency graphs.

You might reject this rule if you believe convenience should win over explicitness, or if you think organizational discipline should come from team culture rather than structural constraints. You might disagree if you work in a small codebase where everyone knows where everything is, making the discoverability benefits less valuable than the ceremony cost. You might prefer allowing vertical dependencies if you value hierarchical reuse patterns over flat dependency graphs, or if you trust developers to keep parent packages clean without structural enforcement.
