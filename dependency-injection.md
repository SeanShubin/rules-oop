# Dependency Injection

## Concept
Classes that delegate to behavioral dependencies should depend on abstractions (interfaces), not concrete implementations. This allows different implementations to be substituted without changing the delegating class, enabling testing with fakes and production with real implementations. Composition roots wire concrete implementations to abstractions at application boundaries, isolating construction decisions from business logic.

## Implementation
- Classes depend on interfaces for behavioral dependencies:
    - I/O operations: databases, file systems, networks, mail services
    - Non-deterministic behavior: random number generators, clocks, UUID generators
    - External systems: payment gateways, APIs, service discovery
    - Anything you need to fake or mock in tests
- Classes can directly use concrete types for:
    - Pure data: domain objects, value objects, entities, DTOs
    - Deterministic transformations: pure functions, utilities
    - Configuration: paths, durations, connection strings
    - Language primitives: strings, numbers, collections
- All dependencies (both interfaces and concrete values) must be constructor-injected
- Composition root classes wire everything together:
    - Create concrete implementations
    - Inject them into classes that need them
    - No business logic in composition roots
- Factories create instances but must themselves be injected through composition roots
- Domain objects know nothing about implementation details (databases, networks, frameworks); implementation classes know about domain objects

### Staged Dependency Injection

When dependencies are not available at compile time (configuration files, service discovery, runtime initialization), break composition into multiple stages. The key principle: **make work vs wiring syntactically visible** so developers can tell what's happening by looking at the code structure.

#### The Core Principle: Syntactic Visibility

**Constructors wire references together (no effects). Methods do work (effects happen here).**

This makes staging explicit and prevents hidden side effects. When you see a constructor call, nothing happens except wiring. When you see a method call, you know work is being done.

#### Two Types of Classes

**1. Composition Roots** - Classes ending in "Dependencies"
- Only contain constructor calls (wiring)
- No method calls that do work
- No logic, conditionals, loops, or calculations
- Pure dependency injection

**2. Service Classes** - Classes that do work
- Have methods that perform operations
- Constructor-inject all dependencies
- Methods contain the logic

#### The Universal Pattern

```kotlin
// Service class - does work via methods
class Bootstrap(
    private val integrations: Integrations  // Constructor-injected dependencies
) {
    private val argsParser = ArgsParser

    fun loadConfiguration(): Configuration {  // Work happens in methods
        val configBaseName = argsParser.parseConfigBaseName(integrations.commandLineArgs)
        val loader = ConfigurationLoader(integrations, configBaseName)
        return loader.load()
    }

    fun loadConfiguration(configBaseName: String): Configuration {  // Overload for external config source
        val loader = ConfigurationLoader(integrations, configBaseName)
        return loader.load()
    }
}

// Composition root - only wiring
class BootstrapDependencies(
    integrations: Integrations
) {
    val bootstrap: Bootstrap = Bootstrap(integrations)  // Only constructor calls
}

// Composition root - only wiring
class ApplicationDependencies(
    integrations: Integrations,
    configuration: Configuration
) {
    private val files = integrations.files
    private val clock = integrations.clock
    // ... more wiring ...
    val runner: Runnable = Runner(clock, /* ... */)
    val errorMessageHolder: ErrorMessageHolder = ErrorMessageHolderImpl()
}

// Entry point orchestrates: wire -> work -> wire -> work
fun execute(args: Array<String>): Int {
    val integrations = ProductionIntegrations(args)           // Stage 1: WIRING

    val bootstrapDeps = BootstrapDependencies(integrations)   // Stage 2: WIRING
    val configuration = bootstrapDeps.bootstrap.loadConfiguration()  // Stage 2: WORK ←

    val appDeps = ApplicationDependencies(integrations, configuration)  // Stage 3: WIRING
    appDeps.runner.run()  // Stage 3: WORK ←

    return if (appDeps.errorMessageHolder.errorMessage == null) 0 else 1
}
```

**What makes this pattern work:**
- You can **see** where work happens (method calls like `.loadConfiguration()`, `.run()`)
- You can **see** where wiring happens (constructors like `BootstrapDependencies(...)`)
- The staging sequence is **explicit** in the entry point, not buried in constructor calls
- Each `XyzDependencies` class is **pure wiring** - easy to verify, nothing to test

#### Why Constructors Must Not Do Work

**The problem with work in constructors:**
```kotlin
// ❌ BAD - Constructor does I/O, hidden from caller
class Bootstrap(integrations: Integrations) {
    val configuration = loadConfigFromDisk(integrations.files)  // Hidden I/O!
}

// Caller can't tell work is happening
val bootstrap = Bootstrap(integrations)  // Looks like wiring, actually does I/O
```

**The solution - work in methods:**
```kotlin
// ✅ GOOD - Constructor only wires
class Bootstrap(private val integrations: Integrations) {
    fun loadConfiguration(): Configuration {  // Work is explicit
        return loadConfigFromDisk(integrations.files)
    }
}

// Caller can see work happening
val bootstrap = Bootstrap(integrations)           // Wiring
val config = bootstrap.loadConfiguration()       // Work - syntactically obvious
```

**Why this matters:**
- **Transparency**: You can trace execution by looking at method calls
- **Testability**: Composition roots with only constructors need no tests
- **Debugging**: Stack traces show method boundaries where work happens
- **Reasoning**: No hidden surprises - constructors always just wire

#### Scaling the Pattern

**If Bootstrap needs more dependencies:**
```kotlin
class Bootstrap(
    private val integrations: Integrations,
    private val validator: ArgsValidator,    // New dependency
    private val defaults: ConfigDefaults      // Another dependency
) {
    fun loadConfiguration(): Configuration { /* ... */ }
}

class BootstrapDependencies(integrations: Integrations) {
    private val validator = ArgsValidator()
    private val defaults = ProductionDefaults
    val bootstrap = Bootstrap(integrations, validator, defaults)  // Still just wiring
}
```

Constructor injection scales to any number of dependencies. Composition roots stay pure wiring.

**If you need more stages:**
```kotlin
fun execute(args: Array<String>): Int {
    val integrations = ProductionIntegrations(args)

    val bootstrapDeps = BootstrapDependencies(integrations)
    val configuration = bootstrapDeps.bootstrap.loadConfiguration()

    val discoveryDeps = ServiceDiscoveryDependencies(integrations, configuration)
    val services = discoveryDeps.serviceDiscovery.discover()

    val appDeps = ApplicationDependencies(integrations, configuration, services)
    appDeps.runner.run()

    return if (appDeps.errorMessageHolder.errorMessage == null) 0 else 1
}
```

The pattern is the same: wire -> work -> wire -> work. EntryPoint orchestrates explicitly.

#### Common Staging Pattern

The pattern generalizes to any number of stages. Each stage follows the same structure:

1. **Create composition root** (XyzDependencies) - wires service class with constructor-injected dependencies
2. **Call service method** - does work, returns result
3. **Pass result to next stage** - result becomes input to next composition root

**Common stages:**
- **Stage 1: Integrations** - Everything that crosses the application boundary (files, clock, network, args). Interface-based to swap prod vs test implementations.
- **Stage 2: Bootstrap** - Parse inputs, load configuration from external sources
- **Stage 3: Application** - Wire domain objects and business logic using integrations + configuration
- **Additional stages** as needed: service discovery, dynamic feature loading, plugin initialization, authentication, authorization, etc.

**The repeating pattern per stage:**
```kotlin
// Stage N
val stageDeps = StageDependencies(inputsFromPreviousStage)  // WIRING
val result = stageDeps.service.doWork()                     // WORK

// Stage N+1
val nextStageDeps = NextStageDependencies(inputsFromPreviousStage, result)  // WIRING
val nextResult = nextStageDeps.service.doWork()             // WORK
// ... continue pattern
```

Each stage's composition root (`XyzDependencies`) does pure wiring, and each service class exposes methods for doing work. The pattern scales to any number of stages without changing structure.

#### Staged Dependency Injection with Concurrent Systems

The staged dependency injection pattern extends naturally to concurrent/async systems. The key insight: **most code lives in concurrent land using `suspend` functions, with `runBlocking` appearing only at the entry point boundary**.

**Architecture Pattern:**

```kotlin
// Entry point - bridges from sequential to concurrent land
fun main(args: Array<String>) = runBlocking {  // ← Enter concurrent land once
    val integrations = ProductionIntegrations(args)  // Wiring

    val bootstrapDeps = BootstrapDependencies(integrations)
    val config = bootstrapDeps.bootstrap.loadConfiguration()  // suspend fun - work in concurrent land

    val appDeps = ApplicationDependencies(integrations, config)
    appDeps.runner.run()  // suspend fun - stays in concurrent land
}

// Service class with suspend functions
class Bootstrap(private val integrations: Integrations) {
    private val argsParser = ArgsParser

    suspend fun loadConfiguration(): Configuration {  // ← suspend, not blocking
        val configBaseName = argsParser.parseConfigBaseName(integrations.commandLineArgs)
        val loader = ConfigurationLoader(integrations, configBaseName)
        return loader.load()  // ← also suspend
    }
}

// All business logic uses suspend functions
interface Database {
    suspend fun query(sql: String): ResultSet
}

interface Notifications {
    suspend fun send(message: String)
}

class Runner(
    private val database: Database,
    private val notifications: Notifications
) {
    suspend fun run() {  // ← suspend, all work happens in concurrent land
        val results = database.query("SELECT ...")
        notifications.send("Processing...")
        // Everything from here is concurrent/async
    }
}
```

**Key Points:**

1. **`runBlocking` appears only at boundaries:**
   - Entry point (`main()` function)
   - Test functions (`@Test fun myTest() = runBlocking { ... }`)
   - Rare cases bridging back to blocking code

2. **Most code uses `suspend` functions:**
   - Business logic: `suspend fun processOrder(order: Order): Result`
   - I/O operations: `suspend fun Database.query(sql: String): ResultSet`
   - Event handlers: `suspend fun handleEvent(event: Event)`
   - All injected interfaces can have suspend methods

3. **Constructor injection still applies:**
   - Dependencies are still constructor-injected
   - Composition roots still do pure wiring
   - Service classes still expose methods for work
   - The only difference: methods are `suspend fun` instead of regular functions

4. **Wiring vs Work separation is preserved:**
   - Constructors still only wire (never `suspend`)
   - Methods do work (now with `suspend`)
   - Composition roots remain pure (no suspend, no work)

**Visualization:**

```
Sequential World (main)
      ↓
  runBlocking { ... }        ← Enter concurrent land ONCE
      ↓
  [All staging and work]     ← Everything uses suspend functions
  - Bootstrap.loadConfiguration()  (suspend fun)
  - ApplicationDependencies creation (wiring, not suspend)
  - Runner.run()                   (suspend fun)
  - Database.query()               (suspend fun)
  - Notifications.send()           (suspend fun)
      ↓
  [Program ends]             ← Still in concurrent land
```

**Why This Works:**

- **Minimal blocking overhead** - Only one `runBlocking` at the entry point
- **Natural concurrency** - All I/O can run concurrently by default
- **Structured concurrency** - Cancellation propagates correctly through the chain
- **Testable** - Tests use `runTest` instead of `runBlocking` for better control

**Testing Concurrent Code:**

```kotlin
@Test
fun testRunner() = runTest {  // ← runTest instead of runBlocking
    val fakeDatabase = FakeDatabase()
    val fakeNotifications = FakeNotifications()
    val runner = Runner(fakeDatabase, fakeNotifications)

    runner.run()  // ← suspend fun, runs in test's concurrent context

    assertEquals(1, fakeDatabase.queryCalls.size)
    assertEquals(1, fakeNotifications.sendCalls.size)
}
```

**Comparison with Blocking Code:**

| Aspect | Blocking (Traditional) | Concurrent (Suspend) |
|--------|----------------------|---------------------|
| Entry point | `fun main(args: Array<String>)` | `fun main(args: Array<String>) = runBlocking { ... }` |
| Service methods | `fun run()` | `suspend fun run()` |
| I/O interfaces | `fun query(sql: String): ResultSet` | `suspend fun query(sql: String): ResultSet` |
| Composition roots | Same (wiring only, no work) | Same (wiring only, no work) |
| Where you live | Sequential land | Concurrent land (after runBlocking) |
| Testing | `@Test fun test()` | `@Test fun test() = runTest { ... }` |

**The Pattern:** Sequential code exists only at application lifecycle boundaries (startup/shutdown). Everything inside lives in concurrent land using `suspend` functions. Dependency injection, staged composition, and the wiring-vs-work separation all remain the same - only the execution context changes from sequential to concurrent.

## Verification Checklists

Use these checklists when reviewing code to ensure complete adherence to dependency injection principles.

### Integrations Completeness Checklist

Verify ALL application boundary crossings are in Integrations - both inputs coming in and outputs going out:

**External Inputs (data entering the application):**
- [ ] **Command-line arguments** - Args array passed from OS/JVM
- [ ] **Environment variables** - System environment, process environment
- [ ] **Standard input** - stdin, console input, Scanner from System.in
- [ ] **Time** - Clock, current timestamp, timers, schedulers

**External Outputs and Services (application interacting with outside world):**
- [ ] **Standard output** - println, System.out, System.err
- [ ] **File system** - Files interface, FileSystem, any paths pointing to real disk
- [ ] **Network** - HTTP clients, sockets, REST APIs, GraphQL clients
- [ ] **Database** - JDBC connections, query executors, ORM sessions
- [ ] **External processes** - ProcessBuilder, Runtime.exec, shell commands
- [ ] **Message queues** - Kafka producers/consumers, RabbitMQ, SQS
- [ ] **Email** - SMTP clients, email senders
- [ ] **Caching** - Redis clients, Memcached (if external)
- [ ] **Random/Non-deterministic** - Random, SecureRandom, UUID generators

**Test:** Can you run your entire application with substituted external interactions by swapping just the Integrations implementation? If not, something is missing.

**Principle:** If it comes from outside your application or goes to the outside world, and you need to substitute it for testing, it belongs in Integrations. The boundary is the key - not whether it's "I/O" in the technical sense, but whether it crosses the application's edge.

**Counter-example (Incomplete Integrations):**
```kotlin
// ❌ BAD - Missing external inputs and hardcoded implementations
interface Integrations {
    val clock: Clock
    val emitLine: (String) -> Unit
    // ❌ Missing: args, files, exec
}

fun main(args: Array<String>) {  // ❌ Args not in Integrations
    val integrations = ProductionIntegrations
    Dependencies(args, integrations).runner.run()  // ❌ Args passed separately
}

class Dependencies(
    args: Array<String>,  // ❌ External input not from Integrations
    integrations: Integrations
) {
    private val files: FilesContract = FilesDelegate  // ❌ Hardcoded!
    private val exec: Exec = ExecImpl()               // ❌ Hardcoded!
    // Cannot test with fake args, FakeFiles, or FakeExec
}
```

**Correct (Complete Integrations):**
```kotlin
// ✅ GOOD - All boundary crossings in Integrations
interface Integrations {
    val commandLineArgs: Array<String>  // ✅ External input
    val clock: Clock
    val emitLine: (String) -> Unit
    val files: FilesContract    // ✅ Swappable
    val exec: Exec              // ✅ Swappable
}

fun main(args: Array<String>) {
    val integrations: Integrations = ProductionIntegrations(args)  // ✅ Args bundled
    Dependencies(integrations).runner.run()  // ✅ Single boundary object
}

class Dependencies(integrations: Integrations) {
    private val args = integrations.commandLineArgs  // ✅ From Integrations
    private val files = integrations.files  // ✅ From Integrations
    private val exec = integrations.exec    // ✅ From Integrations
    // Can test entire app with TestIntegrations(testArgs, FakeFiles(), FakeExec())
}
```

### Composition Root Purity Checklist

Composition roots (classes ending in "Dependencies") should ONLY wire objects together via constructors. They should never do work.

**Key principle: Constructors wire, methods work. If you need to do work, create a service class with a method, then call that method from the orchestrating code (typically EntryPoint).**

**Forbidden in composition roots:**
- [ ] **No method calls that do work** - No `.load()`, `.parse()`, `.calculate()`, `.validate()`, etc.
- [ ] **No conditionals** - No if/when/switch statements (except for null safety on optional dependencies)
- [ ] **No loops** - No for/while/map/filter/fold
- [ ] **No calculations** - No arithmetic, string manipulation, data transformations
- [ ] **No type coercion** - No `.toInt()`, `.toBoolean()`, parsing, conversions

**Acceptable patterns (pure wiring):**
- ✅ Creating instances via constructors: `val x = Y(dependency1, dependency2)`
- ✅ Creating collections: `listOf(report1, report2, report3)`
- ✅ Extracting properties: `val clock = integrations.clock`
- ✅ Method references (not calls): `val handler = notifications::timeTakenEvent`
- ✅ Simple literals: `Paths.get("file.json")`, constants

**Counter-example (Composition Root doing work):**
```kotlin
// ❌ BAD - Composition root contains logic and method calls
class BootstrapDependencies(integrations: Integrations) {
    private val args = integrations.commandLineArgs
    private val argsParser = ArgsParser
    private val configBaseName = argsParser.parseConfigBaseName(args)  // ❌ Method call doing work!

    private val loader = ConfigurationLoader(integrations, configBaseName)
    val configuration = loader.load()  // ❌ Method call doing I/O!
}
```

**Correct (Pure composition root + service class):**
```kotlin
// ✅ GOOD - Service class with work in methods
class Bootstrap(private val integrations: Integrations) {
    private val argsParser = ArgsParser

    fun loadConfiguration(): Configuration {  // Work happens in method
        val configBaseName = argsParser.parseConfigBaseName(integrations.commandLineArgs)
        val loader = ConfigurationLoader(integrations, configBaseName)
        return loader.load()
    }
}

// ✅ GOOD - Composition root with only constructors
class BootstrapDependencies(integrations: Integrations) {
    val bootstrap: Bootstrap = Bootstrap(integrations)  // Only wiring
}

// ✅ GOOD - Orchestration calls methods explicitly
fun execute(args: Array<String>): Int {
    val integrations = ProductionIntegrations(args)

    val bootstrapDeps = BootstrapDependencies(integrations)  // Wiring
    val configuration = bootstrapDeps.bootstrap.loadConfiguration()  // Work - explicit!

    val appDeps = ApplicationDependencies(integrations, configuration)
    appDeps.runner.run()

    return if (appDeps.errorMessageHolder.errorMessage == null) 0 else 1
}
```

**More examples of pure composition roots:**
```kotlin
// ✅ GOOD - Application composition root with pure wiring
class ApplicationDependencies(
    integrations: Integrations,
    configuration: Configuration
) {
    private val clock = integrations.clock
    private val files = integrations.files

    // Direct extraction from config - no loading, no coercion
    private val countAsErrors = configuration.countAsErrors
    private val maxErrors = configuration.maximumAllowedErrorCount
    private val inputDir = configuration.inputDir

    // Simple instantiation - only constructors
    private val observer = ObserverImpl(
        inputDir,
        configuration.sourcePrefix,
        configuration.isSourceFile,
        configuration.isBinaryFile,
        fileFinder,
        nameParser,
        relationParser,
        files,
        configuration.outputDir,
        configuration.useObservationsCache
    )

    // Simple list construction
    private val reports = listOf(
        staticContentReport,
        tableOfContentsReport,
        sourcesReport
    )

    val runner: Runnable = Runner(clock, observer, reports)
    val errorMessageHolder: ErrorMessageHolder = ErrorMessageHolderImpl()
}
```

### Configuration vs Integrations

**Integrations** = Anything that crosses the application boundary
- Raw external inputs: `commandLineArgs`, `environmentVariables`, `stdin`
- External outputs: `stdout`, `stderr`, `emitLine`
- External services: `files`, `clock`, `network`, `database`, `exec`
- Created at entry point
- The boundary itself, not what comes through it

**Configuration** = Structured values derived from parsing/loading external sources
- Examples: `inputDir`, `outputDir`, `maxRetries`, `enableFeatureX`, `configBaseName`
- Parsed/loaded by Bootstrap stage using Integrations
- Just data - no methods, represents application settings after interpretation

**The distinction:** Integrations contains `commandLineArgs: Array<String>` (raw input from OS), while Configuration contains `configBaseName: String` (parsed from args) and `maxRetries: Int` (loaded from config file using `integrations.files`). Integrations is the channel, Configuration is the message.

**Counter-example (Configuration in Integrations):**
```kotlin
// ❌ BAD - Mixing derived configuration with boundary crossings
interface Integrations {
    val clock: Clock
    val emitLine: (String) -> Unit
    val configBaseName: String      // ❌ This is derived from args, not the args themselves!
    val maxRetries: Int             // ❌ This is loaded from a file, not the file system!
}
```

**Correct (Separated):**
```kotlin
// ✅ GOOD - Only boundary crossings in Integrations
interface Integrations {
    val commandLineArgs: Array<String>  // ✅ Raw input from OS
    val environmentVariables: Map<String, String>  // ✅ Raw input from environment
    val clock: Clock
    val emitLine: (String) -> Unit
    val files: FilesContract  // ✅ Used by Bootstrap to load config
    val exec: Exec
}

// Configuration derived by Bootstrap using Integrations
data class Configuration(
    val configBaseName: String,  // ✅ Parsed from integrations.commandLineArgs
    val maxRetries: Int,         // ✅ Loaded from file via integrations.files
    val inputDir: Path,
    val outputDir: Path
)
```

### Red Flags Indicating Violations

When reviewing code, these patterns indicate dependency injection violations:

**In Integrations:**
- ❌ Args passed separately from Integrations to composition roots (`Dependencies(args, integrations)`)
- ❌ Dependencies class instantiates concrete I/O implementations (`= FilesDelegate`, `= ExecImpl()`)
- ❌ Dependencies class or domain classes use I/O not present in Integrations (search for `Files.`, `System.`, `ProcessBuilder`, etc.)
- ❌ Integrations contains derived/parsed values rather than raw external inputs (likely configuration leaking in)
- ❌ Domain classes call static methods on `Files`, `Paths`, `System`

**In Composition Roots:**
- ❌ Calls to `.load()`, `.read()`, `.fetch()`, `.get()` (I/O during wiring)
- ❌ Calls to `.coerceTo*()`, `.parse*()`, `.toInt()` (type conversion during wiring)
- ❌ Contains `if`, `when`, `switch`, `for`, `while`, `map`, `filter`, `fold`
- ❌ Arithmetic operators in non-trivial expressions (`+`, `-`, `*`, `/`, `%`)
- ❌ Multi-line expressions that compute values rather than construct objects
- ❌ More than 200 lines without clear staging separation

**In Tests:**
- ❌ Cannot test full application flow without real file system
- ❌ Cannot test time-dependent behavior (no Clock injection)
- ❌ Tests mock internal collaborators instead of swapping I/O boundaries
- ❌ Integration tests required for basic business logic testing

## Rationale
"Why do command-line args belong in Integrations rather than passed separately?" Args cross the application boundary - they come from outside (user, OS, shell script). In tests, you substitute fake args just like you substitute fake files or fake clocks. Keeping args separate from Integrations means you have two things to swap for testing instead of one. The principle: Integrations captures everything that crosses the boundary, not just things that perform operations. Args are external input that must be substituted, so they belong with other boundary crossings. The fact that args are "just data" (Array<String>) doesn't matter - they're external data requiring substitution, like environment variables or stdin.

"Why not just new up dependencies where needed?" Direct instantiation couples classes to specific implementations. When `OrderService` creates `new SqlDatabase()`, you cannot test `OrderService` without a real database. When dependencies are injected as interfaces, you can test with `FakeDatabase` and run production with `SqlDatabase` without changing `OrderService`.

"What about simple cases where I'll never swap implementations?" The ability to fake dependencies for testing is valuable even if you never change production implementations. A `Clock` interface seems unnecessary until you need to test time-dependent behavior. A `Random` interface seems excessive until you need deterministic tests. The discipline of injecting these dependencies makes testing straightforward.

"Why can value objects stay concrete?" Value objects like `Money`, `Address`, or `User` are pure data with no varying behavior. There's no benefit to hiding `Address` behind an interface - you'd just be adding ceremony. The same `Address` works in tests and production. The distinction is: inject things that do work (behavior), not things that hold data (values).

"Doesn't this create too many interfaces?" Only behavioral dependencies need interfaces. In a typical service class, you might inject 3-5 interfaces (database, mail service, clock, ID generator) but directly use dozens of domain objects and value types. The interface count stays manageable because most types are pure data.

"What about constructors with many parameters?" This often signals a class with too many responsibilities. Split it. However, composition roots legitimately have many parameters because their job is wiring. That's acceptable - composition roots are the only place allowed to know about all the concrete implementations.

"Why ban business logic from composition roots?" Composition roots are hard to test because they create real implementations. Keeping them pure construction (no conditionals, no calculations) means there's nothing to test. All testable logic lives in classes that receive injected dependencies.

"Why must constructors not do work?" When constructors perform I/O, parsing, or logic, that work is hidden from callers. `val bootstrap = Bootstrap(integrations)` looks like pure wiring but secretly reads files, parses config, and validates inputs. The caller cannot tell whether constructing the object is cheap or expensive, synchronous or potentially blocking. This makes reasoning about code difficult - you must read constructor implementations to understand what happens.

The solution: constructors only wire references, methods do work. `val bootstrap = Bootstrap(integrations)` becomes obviously cheap (just stores a reference), while `val config = bootstrap.loadConfiguration()` is obviously doing work (method call). This syntactic distinction makes the flow visible: you can trace execution by looking at method calls, and you know constructors are always fast and safe.

Additionally, composition roots with only constructors need no tests - there's no logic to verify. All testable behavior lives in service classes with methods. This separates "what we wire together" (composition roots, untestable by nature) from "what we do" (service methods, fully testable).

"How does staging help with runtime configuration?" Staging interleaves wiring and work: create Integrations (wire) → load configuration (work) → create ApplicationDependencies (wire) → run application (work). EntryPoint orchestrates this explicitly, making the sequence visible. Each stage is independently testable because dependencies are explicit (constructor parameters) rather than hidden (global state, work in constructors).

Compare hidden staging (work in constructors): `val app = ApplicationDependencies(args)` - impossible to tell what work happens or in what order.

With explicit staging (work in methods):
```kotlin
val integrations = ProductionIntegrations(args)
val bootstrapDeps = BootstrapDependencies(integrations)
val config = bootstrapDeps.bootstrap.loadConfiguration()  // ← work visible here
val appDeps = ApplicationDependencies(integrations, config)
appDeps.runner.run()  // ← work visible here
```

You can see exactly where work happens and in what sequence. The staging is not hidden in constructor chains.

"How does separating integrations enable deep testing?" When all boundary crossings (args, files, clock, network, stdout) are bundled in Integrations, you can test the entire application by swapping one object. Production passes `ProductionIntegrations(realArgs)` with real external interactions. Deep tests pass `TestIntegrations(testArgs, fakeFiles, fakeClock, capturedOutput)`. The entire `ApplicationDependencies` wiring is reused - only the boundary changes. This enables testing through the full dependency chain without mocking internal collaborators. You test `a -> b -> c -> d` with fake boundaries at the edges, rather than testing `a -> b-stub` separately from `b -> c-stub`.

Deep testing advantages: tests real integration, simpler test setup, no mock coordination. Deep testing disadvantages: harder to test edge cases, side effects must be stubbed. Shallow testing advantages: full control over collaborator behavior, scales infinitely, edge cases straightforward. Shallow testing disadvantages: tests know about internal design, more mocking code.

The choice depends on context: side effects must be stubbed (databases, time), complicated collaborators suggest stubbing, deterministic simple classes don't need stubbing. Both strategies are valid. Separated integrations make deep testing practical when appropriate.

"How does AI change the shallow vs deep testing decision?" Traditionally, refactoring is expensive (manual, error-prone), so developers choose shallow testing upfront to avoid future refactoring pain. This leads to over-engineering abstractions "just in case." With AI-assisted refactoring, the economics change: refactoring becomes cheap (AI automates mechanical work), so you can start with deep testing (simpler, tests real integration) and refactor to shallow only when tests become hard to write.

The pattern: start deep, let complexity guide you. When tests require complicated setup or edge cases become unwieldy, ask AI to extract side effects into injected interfaces. AI executes the mechanical refactoring (extract interface, update constructor, wire through composition roots) while you retain architectural decisions (what to extract, where boundaries should be, testing strategy).

Decision authority remains with humans: you decide testing strategy, what to test, when to refactor. AI executes: the mechanical refactoring work, intermediate steps, implementation details. AI has discretion in how to implement, but you control the architectural trade-offs. The benefit: simpler initial code, refactor when complexity justifies it rather than preemptively defending against hypothetical future requirements.

"What's the connection to the Reader monad?" (Side note, not the primary point) The staged dependency injection pattern mirrors the Reader monad from functional programming. Reader threads an environment through computations with signature `Reader env a = env -> a` (environment to result). In OOP, this becomes dependencies-in-constructor, behavior-as-methods: the class takes environment (integrations, configuration) and exposes behavior (runner). The companion factory `fromConfiguration(integrations: Integrations, config: Configuration): Runnable` has the Reader signature - it's a function from environments to results. Each stage is a Reader computation: takes its environment, produces the next stage. The composition is explicit (manual chaining through constructors) rather than implicit (Haskell's do-notation), but the structure is the same.

## Pushback
This rule assumes testability and flexibility are worth the cost of additional interfaces and explicit wiring. It values being able to test each class in isolation over the simplicity of direct instantiation. It assumes you'll benefit from swapping implementations (even if just test vs production) more than you'll suffer from the indirection.

You might reject this rule if you prioritize simplicity over testability, working in a context where testing is less critical (scripts, prototypes, throw-away code). You might disagree if your codebase is small enough that integration tests suffice, making unit test isolation unnecessary. You might prefer concrete dependencies if you value seeing exactly what code runs over the ability to substitute implementations. You might favor directness over flexibility if you trust that your implementations will never change and testing against real dependencies is acceptable.
