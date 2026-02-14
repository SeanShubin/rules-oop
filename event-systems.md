# Event Systems

## Concept
Events and observability concerns (logging, metrics, notifications, diagnostics) should be treated as first-class behavioral dependencies with explicit interfaces and structured data, not as afterthoughts accessed through global singletons. When code emits events or records observations, it should delegate to an injected interface with named methods that accept structured parameters. This makes events testable, eliminates structural duplication in event recording, and preserves structured data for meaningful querying and analysis.

## Implementation
- Define explicit interfaces for event handlers:
    - Named methods for each type of event (e.g., `userLoggedIn()`, `paymentProcessed()`, `configurationLoaded()`)
    - Structured parameters (domain objects, primitives) not pre-formatted strings
    - One method per distinct event type, not generic `log(String message)`
- Inject event handlers as constructor dependencies:
    - Event interfaces are behavioral dependencies like databases or file systems
    - Wire concrete implementations in composition roots
    - Allow switching between production handlers (database, metrics service) and test handlers (in-memory capture)
- Eliminate structural duplication:
    - Extract repeated event recording patterns into named interface methods
    - Example: Instead of `if(log.isDebugEnabled()) { log.debug(...) }` everywhere, create `notifications.operationCompleted(duration, result)`
    - The interface method handles the formatting, filtering, and recording logic once
- Preserve structured data:
    - Pass domain objects and values to event methods, not pre-formatted strings
    - The event producer should not compose strings from event parts
    - The event consumer (implementation) decides how to handle the structured data - formatting, serialization, storage
    - This enables querying, filtering, and aggregation based on structured fields
- No direct access to global output mechanisms:
    - Ban `System.out.println()`, `System.err.println()`, `logger.info()` in production code
    - Exception: Temporary debugging output (remove once the problem is resolved - may need to be committed to debug production issues)
    - Even console applications should inject output dependencies (e.g., inject `(String) -> Unit` instead of calling `System.out` directly)
- Focus events on boundaries:
    - What HTTP request came in? What SQL command was sent to the database?
    - What request was made to an external API? What response was received?
    - Think event sourcing: Can you reproduce the problem? Can you prove the system works correctly?
    - Event producers don't need to know if events become metrics, traces, logs, or notifications - that's the consumer's concern

## Context and Exceptions

Apply these guidelines with judgment:

- **Temporary debugging output**: During active development, `println()` or `System.err.println()` for quick debugging is acceptable. Remove it once the problem is resolved. Sometimes debugging output needs to be committed to investigate production-only issues, but it should still be removed after the investigation completes. If you find yourself keeping the output long-term, formalize it with an event interface.

- **Framework initialization**: With staged dependency injection (see Dependency Injection rule), even framework initialization code can inject output dependencies through the Integrations stage. The only code that might use direct console output is the absolute entry point (main function) before any composition roots are constructed - typically just 2-3 lines creating integrations and starting the bootstrap stage.

- **Simple one-off scripts**: Throwaway scripts or utilities that will never need testing may use direct console output. If the script becomes permanent or needs testing, refactor to use event interfaces.

- **Console applications**: Even applications whose explicit purpose is console interaction should inject their output mechanism (e.g., `emit: (String) -> Unit`) rather than calling `System.out` directly. This maintains testability and allows output redirection.

- **Events at boundaries vs internal details**: Focus on boundary events - interactions with external systems, user requests, database operations. Internal details (method entry/exit, intermediate calculations) rarely need eventing unless debugging a specific issue.

- **Granularity**: Don't create an interface method for every possible observation. Group related events under cohesive interfaces (e.g., `ServerNotifications` with multiple methods, not 50 separate single-method interfaces). The test: do these events share a reason to change?

**Test:** If you need to verify in a test that an event occurred, or if it represents a boundary interaction (HTTP request, database call, external API), it should be behind an injected interface. Only temporary debugging output should use direct console access.

## Examples

### ❌ VIOLATION: Direct stderr access in production code
```kotlin
class SourceFileFinderImpl(private val files: FilesContract) : SourceFileFinder {
    override fun findSourceFiles(...): List<SourceFileInfo> {
        // ...
        if (!files.isDirectory(moduleSourceRoot)) {
            System.err.println("Warning: Source module path is not a directory, skipping: $moduleSourceRoot")
            return
        }
        // ...
    }
}
```

**Why this is bad:**
- Cannot test that the warning was emitted
- Cannot redirect warnings to a log file or monitoring system
- Not injected, so coupled to console output
- String formatting mixed with business logic

**Fix:** Extract to injected event interface
```kotlin
interface SourceFileNotifications {
    fun pathNotDirectory(path: Path)
}

class SourceFileFinderImpl(
    private val files: FilesContract,
    private val notifications: SourceFileNotifications
) : SourceFileFinder {
    override fun findSourceFiles(...): List<SourceFileInfo> {
        // ...
        if (!files.isDirectory(moduleSourceRoot)) {
            notifications.pathNotDirectory(moduleSourceRoot)
            return
        }
        // ...
    }
}

// Production implementation
class ConsoleSourceFileNotifications(private val emit: (String) -> Unit) : SourceFileNotifications {
    override fun pathNotDirectory(path: Path) {
        emit("Warning: Source module path is not a directory, skipping: $path")
    }
}

// Test implementation
class RecordingSourceFileNotifications : SourceFileNotifications {
    val pathsNotDirectory = mutableListOf<Path>()
    override fun pathNotDirectory(path: Path) {
        pathsNotDirectory.add(path)
    }
}
```

### ❌ VIOLATION: Structural duplication in event recording
```kotlin
if (log.isDebugEnabled()) {
    log.debug(String.format("BEFORE: min %d, max %d", computeMin(list), computeMax(list)))
}
// ... operation ...
if (log.isDebugEnabled()) {
    log.debug(String.format("AFTER: min %d, max %d", computeMin(list), computeMax(list)))
}
```

**Why this is bad:**
- Repeated structural pattern (if-isDebugEnabled-debug-format)
- String formatting scattered through code
- Not testable without real logging framework
- Changes to format require updating multiple locations

**Fix:** Extract to named event methods
```kotlin
interface ListNotifications {
    fun listState(caption: String, list: List<Int>)
}

class ListProcessor(private val notifications: ListNotifications) {
    fun process(list: List<Int>) {
        notifications.listState("before", list)
        // ... operation ...
        notifications.listState("after", list)
    }
}

// Production implementation
class LoggingListNotifications(private val log: Logger) : ListNotifications {
    override fun listState(caption: String, list: List<Int>) {
        if (log.isDebugEnabled()) {
            log.debug(String.format(
                "%s: min %d, max %d",
                caption.uppercase(),
                computeMin(list),
                computeMax(list)
            ))
        }
    }
}

// Test implementation
class RecordingListNotifications : ListNotifications {
    val states = mutableListOf<Pair<String, List<Int>>>()
    override fun listState(caption: String, list: List<Int>) {
        states.add(caption to list)
    }
}
```

### ✅ GOOD: Structured events with named interface methods
```kotlin
interface Notifications {
    fun lookupVersionEvent(uriString: String, dependency: GroupArtifactVersionScope)
}

class DependencyResolver(private val notifications: Notifications) {
    fun resolve(dependency: GroupArtifactVersionScope): Version {
        val uri = buildUri(dependency)
        notifications.lookupVersionEvent(uri, dependency)
        return fetchVersion(uri)
    }
}

// Production: emit as structured log line
class LineEmittingNotifications(private val emit: (String) -> Unit) : Notifications {
    override fun lookupVersionEvent(uriString: String, dependency: GroupArtifactVersionScope) {
        emit("group:${dependency.group} artifact:${dependency.artifact} version:${dependency.version} uri:$uriString")
    }
}

// Test: capture events for verification
class RecordingNotifications : Notifications {
    val lookupEvents = mutableListOf<Pair<String, GroupArtifactVersionScope>>()
    override fun lookupVersionEvent(uriString: String, dependency: GroupArtifactVersionScope) {
        lookupEvents.add(uriString to dependency)
    }
}

// Test can verify event occurred
@Test
fun testDependencyLookup() {
    val notifications = RecordingNotifications()
    val resolver = DependencyResolver(notifications)
    resolver.resolve(someDependency)
    assertEquals(1, notifications.lookupEvents.size)
    assertEquals(expectedUri, notifications.lookupEvents[0].first)
}
```

**Why this is good:**
- Named event method communicates what happened
- Structured parameters preserve data
- Injected handler enables testing
- No structural duplication
- Business logic separate from event formatting

### ✅ ACCEPTABLE: Temporary debugging output
```kotlin
fun processOrder(order: Order) {
    println("DEBUG: Processing order ${order.id}")  // Temporary - will remove after debugging
    // ... business logic ...
}
```

**Why acceptable:** Temporary debugging output is pragmatic. Sometimes production issues require debugging in production environments, so temporary output may need to be committed. Remove it once the investigation is complete, or formalize it with an event interface if it proves valuable long-term.

### ✅ ACCEPTABLE: Absolute entry point before composition roots exist
```kotlin
fun main(args: Array<String>) {
    println("Starting application...")  // Before any composition roots exist
    val integrations = ProductionIntegrations(args)
    BootstrapDependencies(integrations).runner.run()
}
```

**Why acceptable:** The absolute entry point (main function) runs before any composition roots exist. After creating Integrations (which bundles args and all other boundary crossings), use staged dependency injection to inject everything through Integrations - see the Dependency Injection rule's "Staged Dependency Injection" section.

## Rationale

"Why not just use a logging framework directly?" Logging frameworks accessed globally make code untestable and create hidden dependencies. When `OrderService` calls `logger.info("Order processed")`, you cannot verify that log statement in tests without complex framework configuration. When events are injected as interfaces, you can test with `RecordingNotifications` and run production with `LoggingNotifications` without changing `OrderService`.

"Isn't this over-engineering for simple logging?" The complexity is the same, just organized differently. Instead of `logger.info("Order processed: " + order.id)` scattered throughout your code, you write `notifications.orderProcessed(order)` once in each location. The event method captures the formatting logic once, eliminating duplication. And now you can test it.

"What about simple println for debugging?" Temporary debugging output is fine - sometimes even necessary to debug production-only issues. The problem is permanent production code that relies on direct console access, because it cannot be tested, redirected, or disabled. Temporary debugging might live through several commits while investigating production issues, but should be removed once the investigation completes. If you find yourself keeping the output long-term, formalize it with an event interface.

"Don't event interfaces create too many interfaces?" Only if you create one interface per event. Group related events under cohesive interfaces. `UserNotifications` might have `userLoggedIn()`, `userLoggedOut()`, `userPasswordChanged()`. These events share a reason to change (user management) and can live together. The test: would changes to one event method likely require changes to others?

"Why pass structured data instead of formatted strings?" The event producer should not compose strings from event parts - that's the consumer's job. If you format `"User 123 logged in"` in the producer and pass that string, you've thrown away structure. Later you need regular expressions to extract the user ID. If you pass `userId: Int, userName: String` to the event method, the event consumer can store it in database columns, format it as JSON, emit metrics, or create a log line - whatever the consumer needs. The producer remains decoupled from how events are consumed.

"How do I know what events to capture?" Focus on boundaries: What HTTP request came in? What SQL was sent to the database? What API call was made? Think event sourcing: Can you reproduce a production problem in development? Can you audit that the system behaved correctly? These questions guide event design. Capture boundary interactions with enough structured detail to replay or verify behavior.

"What about performance-sensitive code?" Event method calls are function calls with the same overhead as any other method. If you need to avoid even that overhead, inject a no-op implementation. But premature optimization is rarely warranted - measure first. The testability and clarity usually outweigh any performance concern.

"Doesn't this make events a big design decision?" Yes, deliberately. Events are how you understand production behavior. They're worth designing intentionally rather than scattering println and logger calls ad-hoc. When events are first-class concerns with explicit interfaces, you make conscious decisions about what to observe and how to structure the data.

"What about metrics, tracing, logging - are they different?" From the event producer's perspective, no. The producer emits structured events at boundaries. Whether the consumer turns those events into metrics, distributed traces, log lines, or notifications is the consumer's concern. The producer remains decoupled. A single event like `databaseQueryExecuted(query, duration)` might be consumed as a metric (query count, latency), a trace span (distributed tracing), and a log line (debugging) simultaneously by different consumers.

"What about diagnostic events that happen everywhere?" Focus on boundary events, not internal implementation details. Method entry/exit tracing and fine-grained profiling are debugging concerns that might justify temporary instrumentation, but production events should capture meaningful boundary interactions. If you find yourself emitting events from every method, you're likely capturing too much detail rather than focusing on architecturally significant boundaries.

## Pushback
This rule assumes that testability, structured data preservation, and explicit event design are worth the cost of defining interfaces and injection. It values being able to verify event behavior in tests and query structured event data over the convenience of calling logger methods directly. It assumes you'll benefit from testing event logic and analyzing event data more than you'll suffer from the indirection of interfaces.

You might reject this rule if you prioritize simplicity over testability, working in contexts where event testing is unnecessary (scripts, prototypes, throw-away code). You might disagree if your codebase is small enough that console output suffices and structured querying provides no value. You might prefer direct logging if you trust your logging framework's testing utilities and believe the global logger pattern is simpler than injection. You might favor convenience if you work in domains where event analysis is rare and the effort of designing event interfaces exceeds their benefit.
