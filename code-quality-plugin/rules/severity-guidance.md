# Severity Guidance: When Rules Matter Most

This guide helps you distinguish between critical violations that must be fixed and patterns that are acceptable in context. The goal is to prevent genuine maintainability problems without creating false alarms for reasonable design choices.

Priority is based on structural criticality - problems affecting architecture and how code changes take precedence over local readability concerns.

## High Severity (Must Fix)

These violations create problems that multiply - changes become exponential, testing becomes impossible:

### 1. **Scattered Changes**
- **Single feature requires editing many unrelated files**
- **Why it matters:** Indicates poor cohesion. Adding a feature becomes exponential work - you must understand and coordinate changes in multiple places that shouldn't need to know about each other.
- **Example:** "To add a payment method, I must change files in payments, orders, checkout, and users"
- **Rule:** Coupling and Cohesion
- **Action:** Move related code closer together; group code that changes together

### 2. **Code That Changes Together Is Separated**
- **Related logic split across packages or classes**
- **Why it matters:** A single logical change requires hunting through the codebase. Changes scatter instead of being localized.
- **Example:** CRUD operations for a data structure in four different classes
- **Rule:** Coupling and Cohesion
- **Action:** Group by reason to change

### 3. **Concrete Dependencies for Testable Behavior**
- **Classes directly instantiating other classes that do I/O or have non-deterministic behavior**
- **Why it matters:** Cannot verify correctness without real infrastructure. Makes testing impossible without real databases, networks, or clocks.
- **Example:** `class OrderService { private val db = SqlDatabase("prod-connection") }`
- **Rule:** Dependency Injection
- **Action:** Accept interface via constructor: `class OrderService(private val db: Database)`

### 4. **Business Logic Mixed with Infrastructure**
- **Domain operations containing HTTP calls, SQL queries, or file I/O in the same method**
- **Why it matters:** Cannot test business logic without infrastructure; cannot change data structures without understanding networking code, or vice versa.
- **Example:** Method that validates order AND writes to database in same method body
- **Rule:** Dependency Injection
- **Action:** Separate into orchestration (business logic) and execution (infrastructure calls)

## Medium Severity (Should Fix)

These violations hide structure - understanding flow requires parsing details, cycles prevent isolation:

### 1. **Long Methods Mixing Abstraction Levels**
- **Methods with 50+ lines mixing orchestration with implementation details**
- **Why it matters:** Understanding the high-level flow requires parsing low-level mechanics. Changes to how something works require understanding what coordinates it.
- **Example:** Method that coordinates business logic AND contains string parsing, bit manipulation, or complex algorithms inline
- **Rule:** Abstraction Levels
- **Action:** Extract implementation details to named helper methods

### 2. **High-Level Code Knowing Low-Level Details**
- **Orchestration code that understands implementation mechanics**
- **Why it matters:** Changes to mechanics require changing coordination code. The separation of concerns is broken.
- **Example:** Business logic method that knows about HTTP headers, SQL syntax, or binary formats
- **Rule:** Abstraction Levels
- **Action:** Create intermediate abstractions that hide implementation details

### 3. **Cyclic Dependencies Between Modules**
- **Modules with circular dependencies**
- **Why it matters:** Cannot understand one module without understanding all others in the cycle. Modules are release units - cycles prevent independent versioning and deployment.
- **Example:** `payments` module imports from `orders` module, `orders` imports from `inventory`, `inventory` imports from `payments`
- **Rule:** Package Hierarchy
- **Action:** Break the cycle by extracting shared concepts to a new module, or inverting a dependency through an interface

### 3a. **Cyclic Dependencies Within Modules**
- **Packages within the same module with circular dependencies**
- **Why it matters:** Still indicates tight coupling and makes code hard to understand, but impact is localized to one release unit
- **Example:** `com.company.model.api` imports from `com.company.model.conversion`, which imports from `com.company.model.api`
- **Rule:** Package Hierarchy
- **Action:** Same as above - extract shared concept or invert dependency
- **Note:** Lower severity than module-level cycles because it doesn't affect external consumers

### 4. **Vertical Dependencies**
- **Parent packages depending on child packages**
- **Why it matters:** The hierarchy inverts and navigation becomes confusing. Parent should be more general than children.
- **Example:** `payments` package code imports from `payments.creditcard`
- **Rule:** Package Hierarchy
- **Action:** Move code down to child, or up to parent, or extract shared concept to sibling

### 5. **Parent Packages Containing Code**
- **Non-leaf packages with actual classes/functions alongside child packages**
- **Why it matters:** Creates hidden dependencies and dumping ground for "shared" code
- **Example:** `payments` package contains `Utils.kt`, and also has `payments.creditcard`, `payments.paypal` subpackages
- **Rule:** Package Hierarchy
- **Action:** Move code to explicitly-named sibling: `payments.shared` or down into specific subpackages

### 6. **Large Packages with Mixed Concerns**
- **Packages with 30+ files that don't share a clear reason to change**
- **Why it matters:** Makes navigation difficult; increases risk of unintended coupling
- **Test:** Look at recent commits. Do unrelated features touch this package? That's the problem.
- **Rule:** Coupling and Cohesion
- **Action:** Split by domain concern or reason-to-change. Ask "what changes together?"

### 7. **Events Accessed Globally Instead of Injected**
- **Direct System.out/System.err or global logger calls in production code**
- **Why it matters:** Cannot test event behavior; cannot redirect events; creates hidden dependencies. Boundary interactions (HTTP requests, database calls) go unverified.
- **Example:** `System.err.println("Warning: ...")` instead of `notifications.warning(...)`
- **Rule:** Event Systems
- **Action:** Define event interface with named methods, inject it, implement for production and testing
- **Exception:** Temporary debugging output (may need to be committed to debug production issues, but remove once investigation is complete)

### Module Boundary Violations vs Package Organization

Understanding the distinction between module and package violations helps prioritize fixes:

**High Severity - Module dependency violations:**
- Cyclic dependencies between modules (separate release units depending on each other)
- Module depending on implementation details of another module
- Module dependencies that violate domain layering (infrastructure depending on domain)
- **Why critical:** Module boundaries are architectural - they affect what consumers must depend on and version (REP). Breaking module dependency rules forces consumers to take unwanted code (CRP).

**Medium Severity - Package violations within modules:**
- Cyclic dependencies within a module (still enforced, but impact is localized)
- Parent-child package dependencies within a module
- Package organization that confuses navigation
- **Why less critical:** Package boundaries within modules are organizational - they affect how developers navigate code but don't impact external consumers or release management.

**The difference:** Module violations have broader impact because modules are versioned release units. Package violations within modules are still real problems (they make code harder to understand and change), but the damage is contained within one release unit.

## Low Severity (Consider Context)

These violations hide intent locally or affect tooling - significant but less structurally critical:

### 1. **Anonymous Code in Parameter Lists**
- **Expressions with operators in function/method calls**
- **Why it matters:** Hides intent. Readers must mentally execute mechanics to infer purpose. However, impact is local to individual statements.
- **Example:** `calculate(x + 5, y * 0.08)` - what do these numbers mean?
- **Rule:** Anonymous Code
- **Action:** Extract to named variables: `val total = x + 5; val tax = y * 0.08; calculate(total, tax)`

### 2. **Explanatory Comments for What Code Does**
- **Comments explaining mechanics instead of letting code structure communicate**
- **Why it matters:** Code structure should be self-documenting through names. Comments for "what" indicate unclear code.
- **Example:** `// calculate tax` followed by `x * 0.08`
- **Rule:** Anonymous Code
- **Action:** Extract to named function: `calculateTax(x)`
- **Note:** Comments explaining "why" (business rules, external references) are valuable

### 3. **Mixed Languages in String Literals**
- **HTML or CSS embedded as string literals in application code**
- **Why it matters:** Lose syntax highlighting, validation, and refactoring support from tools. Languages cannot be edited in their native contexts.
- **Example:** `val html = "<div class='$statusClass'><h2>$title</h2></div>"`
- **Rule:** Language Separation
- **Action:** Use structured representations for HTML (Tag/Text), resource files for CSS
- **Exception:** Runtime-calculated CSS values like `style="width: ${percent}%"` are acceptable when values are only known at runtime

### 4. **Free Floating Public Functions**
- **Public functions at package level without namespace containers**
- **Why it matters:** Slows discovery - finding functionality requires knowing which package to search. Namespaced containers provide logical groupings.
- **Example:** `fun validateUser(...)` at package level instead of in `UserValidator` object
- **Rule:** Free Floating Functions
- **Action:** Wrap in namespaced container (object, class) for discoverability

### 5. **Type Operations in Heterogeneous Collections**
- **Casting or type checks when working with `Map<K, Any>` or dynamically-typed structures**
- **When acceptable:** The heterogeneity is inherent to the domain (JSON, JVM constant pools, dynamic configs)
- **When not:** You created `Map<String, Object>` to avoid proper types
- **Test:** Could you eliminate the casting with better types? If no (external format dictates structure), it's acceptable.

### 6. **Private Helper Methods**
- **Private methods that serve the class's single responsibility**
- **When acceptable:** `hexFormat()` in a Formatter, `sanitizeInput()` in a Validator - helpers cohesive with the class
- **When not:** `calculateTax()` in an OrderService that should be in TaxCalculator
- **Test:** If you extracted this helper to a separate class, would it have a clear responsibility? If no, keep it private.

### 7. **Standard Organizational Patterns**
- **api/impl split, interface/implementation, public/internal packages**
- **When acceptable:** Pattern is established in the codebase and aids navigation
- **When not:** Fighting a familiar pattern for theoretical purity
- **Test:** Does the pattern help developers find what they need? If yes, keep it.

### 8. **Package Organization Within a Module**
- **Packages organized by technical concern within a single cohesive module**
- **When acceptable:** No cycles, no vertical dependencies, serves organizational needs
- **When not:** Crosses module boundaries, creates coupling between teams
- **Test:** Is this one team's one module? If yes, organizational flexibility is okay.

### 9. **Small Packages with Multiple Concerns**
- **Packages with under 15 files even if not perfectly cohesive**
- **When acceptable:** Package is easy to navigate, no actual maintenance problems
- **When not:** Package keeps growing or appears in commits for unrelated work
- **Test:** Is navigation easy? Do developers know where to add new code? If yes, size is fine.

## Not Violations

These patterns are explicitly acceptable and should not be flagged:

### 1. **Runtime-Calculated CSS Values**
- **Inline style attributes with values calculated at runtime**
- **Example:** `<div style="width: ${percentage}%">` for progress bar, `style="background-color: ${user.themeColor}"`
- **Why acceptable:** Values are only known at runtime. Static styles remain in CSS files, dynamic values are inline.
- **Test:** Could this value be determined when writing the code? If no (percentage from database, user's chosen color), inline is fine.

### 2. **Interface Convenience Methods**
- **Default methods in interfaces that combine lower-level operations**
- **Example:** `default String lookupName(int index) { return get(index).name(); }`
- **Why acceptable:** Provides useful abstraction, reduces duplication in implementations

### 3. **Necessary Domain Complexity**
- **Type dispatch in parsers, visitors, serializers, or dynamic data structures**
- **Example:** JSON serializer checking if value is Map, List, String, Number, etc.
- **Why acceptable:** The type checking IS the domain logic, not incidental mechanics

### 4. **Cohesive Helper Methods**
- **Private methods that would have no clear home if extracted**
- **Example:** `formatTimestamp()` in a ReportGenerator
- **Why acceptable:** Creating a "TimestampFormatter" for one use is ceremony, not clarity

### 5. **Standard Design Patterns**
- **Factory, Strategy, Visitor, Builder when they solve real problems**
- **Why acceptable:** Widely understood patterns that communicate intent
- **Caution:** Don't use patterns for their own sake, only when they solve a real problem

## When in Doubt: The Practical Tests

If you're unsure whether something is a violation, ask these questions:

### 1. **Does this cause actual confusion?**
- Have new developers asked about this code?
- Do code reviews require explaining the organization?
- If no, it's probably fine.

### 2. **Do changes scatter?**
- Look at the last 10 commits related to this area
- Does a single feature touch 5+ unrelated files?
- If yes, cohesion is genuinely low.

### 3. **Can you test it?**
- Can you write a unit test without a database, network, or filesystem?
- If no, dependency injection is genuinely needed.

### 4. **Would refactoring make it clearer?**
- Would extracting this create a class/method with clear responsibility?
- Or would it just move complexity without reducing it?
- If the latter, leave it alone.

### 5. **What's the maintenance history?**
- Has this code been stable, or does it change frequently?
- Do changes cause unexpected breakage elsewhere?
- If stable and localized, it's working.

## Summary: Focus on Real Problems

Priority is based on structural criticality - architecture before local concerns.

**Fix immediately (High Severity):**
- Scattered changes - single feature touches many unrelated files
- Code that changes together is separated
- Cannot test without real infrastructure
- Business logic mixed with I/O

**Fix when opportune (Medium Severity):**
- Long methods mixing abstraction levels
- High-level code knowing low-level details
- Cyclic dependencies
- Vertical dependencies (parent depends on child)
- Parent packages containing code
- Large packages (30+ files) mixing concerns

**Consider context (Low Severity):**
- Anonymous code in parameter lists
- Explanatory comments for what code does
- Mixed languages in string literals (HTML/CSS)
- Free floating public functions
- Type operations in heterogeneous data
- Private helpers serving the class
- Standard patterns (api/impl)
- Small packages (<15 files)

**Don't flag as violations:**
- Runtime-calculated CSS (progress bars, dynamic colors)
- Interface convenience methods
- Domain complexity (parsers, visitors)
- Cohesive private helpers
- Patterns solving real problems

The goal is maintainable code, not perfect compliance. When the rules conflict with practical reality, favor clarity and working code over theoretical purity.
