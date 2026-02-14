# Coupling and Cohesion

## Concept
Code should be organized so that elements that change together are grouped together, and elements that change for different reasons are kept separate. This minimizes the scope of change - when requirements evolve, modifications should be localized rather than scattered. The goal is high cohesion within boundaries and low coupling across boundaries.

## Implementation
- Group code that changes together for the same reason:
    - CRUD operations (read, insert, update, delete) belong together when they all change if the data structure changes
    - Related domain operations that share the same business rules
    - Infrastructure code that changes when a technical decision changes (database, framework, protocol)
- Separate code that changes for different reasons:
    - Different business domains should be in different packages
    - Different infrastructure concerns should be in different modules
    - Code with different reasons to change should be in different classes
- Test by asking: "If X changes, what code needs to change?"
    - If unrelated code would need changes, separation is insufficient
    - If the same change scatters across many places, cohesion is insufficient
- At package level: organize by business domain first, not technical layers
    - Group by feature/domain: payments.creditcard, payments.paypal
    - Not by technical function: controllers/, services/, repositories/
- At class level: group related operations that share a reason to change
- At method level: group operations that always change together

## Context and Scale

Apply these guidelines with judgment:

- **API/Implementation split is acceptable**: Separating interfaces from implementations (e.g., `model/api/` and `model/implementation/`) is a standard pattern that aids testability and dependency management. This is NOT a violation of "organize by domain first" - the domain is the model, and splitting interface from implementation is a technical organization choice within that domain. This pattern is widely understood and helps developers quickly find what they need.

- **Size thresholds matter**: A package with 10-15 files is manageable and easy to navigate. A package with 50+ files likely has mixed concerns and becomes difficult to browse. Use file count and change patterns, not strict rules. The question isn't "are these files perfectly cohesive?" but "is this package too large to understand?"

- **Technical organization for utilities**: Infrastructure packages (collections, time, formatting) organized by technical concern are appropriate when they serve multiple domains. These are cross-cutting by nature. A `StringFormatter` that serves payments, orders, and users doesn't belong in any one domain - it belongs in a shared utility package. The key test: does it serve one domain or many?

- **Module boundaries matter more than package boundaries**: Dependencies between packages in the SAME module are less concerning than dependencies between MODULES. Within a module, packages provide organizational convenience. Between modules, dependencies create architectural constraints. Package organization is preference; module boundaries are architecture. A package dependency within the domain module is different from a domain-to-infrastructure module dependency.

- **Standard patterns are acceptable**: Common organizational patterns (api/impl, interface/implementation, public/internal) are widely understood. Don't violate them for theoretical purity if they're working. The cost of fighting familiar patterns often exceeds the benefit.

- **Module granularity and reuse**: Modules are release boundaries. Apply REP (Reuse-Release Equivalence Principle): what you bundle together should be reused together. Multiple packages in one module are fine if they're cohesively related and consumers typically need them together. Split into separate modules when:
  - Consumers consistently need only some packages (violates Common Reuse Principle)
  - Different packages have different release cadences
  - Independent versioning would benefit consumers

  But don't over-modularize: if packages always deploy together with no external consumers, separate modules add versioning ceremony without benefit. The test: "Do consumers with independent schedules exist?" If no, consider consolidating.

**Test:** Track actual changes over 6 months. Do changes scatter across "should be separate" code? That's genuine coupling. Do unrelated features touch the same files? That's low cohesion. But if the organization works and changes stay localized, don't refactor based on theoretical concerns.

## Rationale
"How do I know if things are related?" Ask what changes together. If changing the database schema requires updating four CRUD methods, they're related - keep them together. If adding a business rule only affects one service class, that concern is properly isolated.

"Isn't this just the Single Responsibility Principle?" Yes. SRP says "one reason to change" - this rule shows how to achieve that through grouping (same concern in one place) and separation (different concerns in different places).

"Why organize packages by domain instead of technical layers?" When you add a new payment method, you want all payment logic in one place. Layered architecture (controllers/, services/, repositories/) scatters a single feature across multiple directories. Domain-first organization (payments/, orders/, users/) keeps related changes together.

"Can you over-separate?" Yes. If you split four CRUD operations into four classes, a schema change requires changing four classes instead of one. They were cohesive - they belonged together. Over-separation destroys cohesion and increases coupling.

"What about shared technical concerns that cross domains?" Generic implementations that serve multiple domains (database connection pooling, logging frameworks, authentication systems) go in their own modules at the root level, organized by responsibility. Domain-specific implementations (how payments accesses data, how orders sends email) belong within their respective domain packages.

"When is api/impl separation appropriate?" When you have multiple implementations (production, test, mock) or when the interface needs to be visible to clients without exposing implementation details. If you have one interface and one implementation that only that interface uses, consider whether the separation adds value. But if this pattern is established in your codebase, don't fight it - consistency has value.

"What about mixed concerns in one package?" Ask: do these files change together? A package with 12 related files is cohesive. A package with 50 files representing 5 different concerns should probably be 5 packages. The file count alone doesn't determine cohesion - the reason-to-change patterns do.

## Pushback
This rule assumes that change locality is worth the cost of additional structure. It values being able to understand and modify one concern without touching others. It assumes code will be maintained and modified over time, so optimizing for change is worthwhile.

You might reject this rule if you're writing throwaway code where modification costs don't matter. You might disagree if you believe fewer, larger units are easier to understand than many small cohesive units. You might prefer technical layering if you value seeing all controllers or all repositories together. You might favor simplicity over structure if your codebase is small enough that scattered changes are manageable.
