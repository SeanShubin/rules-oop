# Test Orchestrator Pattern

**Category:** Testing Practice
**Status:** Guideline (not prioritized with architectural rules)

## Concept

Tests should use a **Test Orchestrator** (often called "Tester") that hides infrastructure complexity and exposes a domain-focused, declarative API for interacting with the system under test. The Tester's job is to make tests readable by presenting data in human-understandable form, so test assertions are obvious. This makes tests readable, maintainable, and resilient to implementation changes.

## The Pattern

### Structure

1. **Create fake/stub dependencies** that provide controllable behavior
2. **Create a Tester class** that:
   - Constructs the system under test with fake dependencies
   - Hides all infrastructure complexity (DOM manipulation, HTTP, JSON serialization, async handling)
   - Hides internal stub implementations (tests never access `tester.stubName`, only `tester.method()`)
   - Presents data in human-readable form (decode hex, format bytes, convert raw data to meaningful strings)
   - Exposes **setup methods** for configuring fake behavior
   - Exposes **action methods** representing user/system actions
   - Exposes **query methods** for making assertions
3. **Tests use the Tester** in given-when-then style
4. **Tests read declaratively** without low-level implementation details

### Benefits

- **Tests are readable:** Domain language, not technical details
- **Test assertions are obvious:** Human can immediately understand what's being verified
- **Tests are resilient:** Implementation changes don't break tests (only Tester needs updating)
- **Tests are maintainable:** Common setup logic is in one place
- **Tests document behavior:** Reading tests shows what the system does
- **Refactoring is safe:** Change implementation, tests still pass

## Examples

### React Component Test (JavaScript)

```javascript
// Test Orchestrator
const createTester = async () => {
    const backend = createBackend({
        listProfilesResults: [[], []]  // empty, then will have added profile
    })
    const updateSummary = jest.fn()
    let rendered
    await act(async () => {
        rendered = render(
            <SummaryContext.Provider value={{updateSummary}}>
                <Profile backend={backend}/>
            </SummaryContext.Provider>
        )
    })

    // Action methods
    const clickDeleteButton = async profileId => {
        await act(async () => {
            const button = rendered.getByLabelText(profileId)
            userEvent.click(button)
        })
    }

    const typeProfileName = async name => {
        await act(async () => {
            const profileNameDataEntry = rendered.getByPlaceholderText('new profile')
            userEvent.type(profileNameDataEntry, name)
        })
    }

    const pressKey = async key => {
        await act(async () => {
            const profileNameDataEntry = rendered.getByPlaceholderText('new profile')
            fireEvent.keyUp(profileNameDataEntry, {key})
        })
    }

    // Query methods
    const isProfileDisplayed = name => {
        return rendered.queryByText(name) !== null
    }

    const wasProfileAdded = name => {
        return backend.addProfile.mock.calls.some(call => call[0] === name)
    }

    const wasSummaryUpdated = () => {
        return updateSummary.mock.calls.length > 0
    }

    // Return orchestrator interface
    return {
        clickDeleteButton,
        typeProfileName,
        pressKey,
        isProfileDisplayed,
        wasProfileAdded,
        wasSummaryUpdated
    }
}

// Test using orchestrator
test('add profile', async () => {
    // given
    const tester = await createTester()
    const profileName = "Alice"

    // when
    await tester.typeProfileName(profileName)
    await tester.pressKey('Enter')

    // then
    expect(tester.isProfileDisplayed(profileName)).toBeTruthy()
    expect(tester.wasProfileAdded(profileName)).toBeTruthy()
    expect(tester.wasSummaryUpdated()).toBeTruthy()
});
```

**What the Tester hides:**
- React rendering setup
- Context providers
- DOM queries (getByPlaceholderText, getByLabelText)
- Async handling (act)
- Mock setup

**What tests see:**
- `typeProfileName(name)` - action
- `pressKey(key)` - action
- `clickDeleteButton(id)` - action
- `isProfileDisplayed(name)` - query
- `wasProfileAdded(name)` - query
- `wasSummaryUpdated()` - query

### Java Unit Test

```java
@Test
public void testMessageDigestForDirectory() {
    // given
    String pathName = "the-path";
    int bufferSize = 3;
    Tester tester = new Tester(bufferSize);
    tester.addFile("the-path/file-a.txt", "abcdefg");
    tester.addFile("the-path/file-b.txt", "hij");
    String expected = "digest for: abc, def, g, hij, klm, n";
    String expectedEvents =
            "Processing file 'the-path/file-a.txt' of size 7 bytes\n" +
            "Processing file 'the-path/file-b.txt' of size 3 bytes";

    // when
    String actual = tester.messageDigestForDirectory(pathName);

    // then
    assertEquals(expected, actual);
    assertEquals(expectedEvents, tester.getEvents());
}

// Tester inner class
static class Tester {
    final MessageDigestStub messageDigest;
    final FilesStub files;
    final ProcessingFileEventStub processingFileEvent;
    final MessageDigestUtilityInverted messageDigestUtility;

    public Tester(int bufferSize) {
        this.messageDigest = new MessageDigestStub();
        this.files = new FilesStub();
        this.processingFileEvent = new ProcessingFileEventStub();
        this.messageDigestUtility = new MessageDigestUtilityInverted(
                messageDigest,
                files,
                bufferSize,
                processingFileEvent
        );
    }

    void addFile(String fileName, String content) {
        files.addFile(fileName, content);
    }

    String messageDigestForDirectory(String pathName) {
        Path path = Paths.get(pathName);
        byte[] messageDigestBytes = messageDigestUtility.messageDigestForDirectory(path);
        return new String(messageDigestBytes);
    }

    String getEvents() {
        return String.join("\n", processingFileEvent.events);
    }
}
```

**What the Tester hides:**
- Stub creation (MessageDigestStub, FilesStub, ProcessingFileEventStub)
- System under test construction
- Path conversions
- Byte array to string conversions

**What tests see:**
- `addFile(filename, content)`
- `messageDigestForDirectory(path)`
- `getEvents()`

### Kotlin Full Application Test (Deep Testing with Staged DI)

This example demonstrates how the Test Orchestrator pattern integrates with Staged Dependency Injection to enable deep testing - testing the entire application with fake integrations at the boundary.

```kotlin
class ApplicationTester(
    private val applicationRunner: (Integrations) -> Int  // ← Takes function reference
) {
    private val fakeFileContents = mutableMapOf<String, List<String>>()
    private val fakeBinaryFiles = mutableMapOf<String, ByteArray>()
    private val capturedOutput = mutableListOf<String>()
    private val retryIntervals = mutableListOf<Long>()
    private var fakeHttpClient: FakeHttpClient = FakeHttpClient()
    private var fakeClock: () -> Instant = { Instant.parse("2024-01-15T10:30:00Z") }

    // Setup methods - configure fake behavior
    fun setupConfigFile(
        fileName: String,
        sourceDirectory: String,
        outputFormat: String,
        archiveServerUrl: String,
        maxRetries: Int = 3,
        retryDelayMillis: Long = 1000,
        bufferSize: Int = 8192
    ) {
        val lines = listOf(
            "source-directory=$sourceDirectory",
            "output-format=$outputFormat",
            "archive-server-url=$archiveServerUrl",
            "max-retries=$maxRetries",
            "retry-delay-millis=$retryDelayMillis",
            "buffer-size=$bufferSize"
        )
        fakeFileContents[fileName] = lines
    }

    fun setupSourceFile(fileName: String, content: String) {
        fakeBinaryFiles[fileName] = content.toByteArray()
    }

    fun setupHttpClient(timesToFailBeforeSuccess: Int) {
        fakeHttpClient = FakeHttpClient(timesToFailBeforeSuccess)
    }

    fun setClock(instant: Instant) {
        fakeClock = { instant }
    }

    // Action method - returns exit code
    fun runApplication(configFileName: String): Int {
        val fakeFiles = FakeFiles(fakeFileContents)
        fakeBinaryFiles.forEach { (fileName, content) ->
            fakeFiles.addBinaryFile(fileName, content)
        }

        val fakeMessageDigest = FakeMessageDigest()
        val exitCode = ExitCodeImpl()

        val testIntegrations: Integrations = TestIntegrations(
            commandLineArgs = arrayOf(configFileName),
            files = fakeFiles,
            messageDigest = fakeMessageDigest,
            httpClient = fakeHttpClient,
            sleep = { millis -> retryIntervals.add(millis) },
            clock = fakeClock,
            emitLine = { line -> capturedOutput.add(line) },
            exitCode = exitCode
        )

        return applicationRunner(testIntegrations)  // ← Calls injected function
    }

    // Query methods - for assertions
    fun outputContains(text: String): Boolean {
        return capturedOutput.any { it.contains(text) }
    }

    fun getOutputLineCount(): Int = capturedOutput.size

    fun getRetryIntervals(): List<Long> = retryIntervals.toList()

    fun getUploadAttemptCount(): Int = fakeHttpClient.getAttemptCount()
}

// Test using orchestrator
@Test
fun `full application flow with fake integrations`() {
    // given
    val tester = ApplicationTester(::execute)  // ← Pass execute function reference
    tester.setupConfigFile(
        fileName = "test-config.txt",
        sourceDirectory = "source",
        outputFormat = "JSON",
        archiveServerUrl = "https://archive.example.com/upload"
    )
    tester.setupSourceFile("source/file1.txt", "Hello, World!")
    tester.setupSourceFile("source/file2.txt", "Goodbye!")

    // when
    val exitCode = tester.runApplication("test-config.txt")

    // then
    assertEquals(0, exitCode)
    assertTrue(tester.outputContains("Upload successful"))
}

@Test
fun `returns exit code on network error`() {
    // given
    val tester = ApplicationTester(::execute)
    tester.setupConfigFile(
        fileName = "test-config.txt",
        sourceDirectory = "source",
        outputFormat = "JSON",
        archiveServerUrl = "https://archive.example.com/upload",
        maxRetries = 3
    )
    tester.setupSourceFile("source/file.txt", "content")
    tester.setupHttpClient(timesToFailBeforeSuccess = Int.MAX_VALUE)  // Always fail

    // when
    val exitCode = tester.runApplication("test-config.txt")

    // then
    assertEquals(3, exitCode)  // Network error exit code
    assertEquals(3, tester.getUploadAttemptCount())
}
```

**What the ApplicationTester hides:**
- FakeFiles, FakeBinaryFiles, FakeMessageDigest, FakeHttpClient construction
- ExitCodeImpl creation
- TestIntegrations wiring (all 8 integrations)
- Output capture mechanism
- Retry interval tracking
- HTTP attempt counting
- All three stages of the application (Bootstrap → Manifest Building → Application)

**What tests see:**
- `setupConfigFile(fileName, sourceDirectory, outputFormat, archiveServerUrl, ...)`
- `setupSourceFile(fileName, content)`
- `setupHttpClient(timesToFailBeforeSuccess)`
- `setClock(instant)`
- `runApplication(configFileName)` → Int
- `outputContains(text)` → Boolean
- `getOutputLineCount()` → Int
- `getRetryIntervals()` → List<Long>
- `getUploadAttemptCount()` → Int

**Integration with Staged Dependency Injection:**

The ApplicationTester takes a function reference, making it reusable for any function with signature `(Integrations) -> Int`:

```kotlin
// Production (in main)
fun main(args: Array<String>) {
    val integrations: Integrations = ProductionIntegrations(args)
    val exitCode = execute(integrations)  // ← execute wraps runApplication with exception handling
    exitProcess(exitCode)
}

fun execute(integrations: Integrations): Int {
    return try {
        runApplication(integrations)
        ExitCodes.SUCCESS
    } catch (e: ApplicationException) {
        System.err.println("Error: ${e.message}")
        e.exitCode
    } catch (e: Exception) {
        System.err.println("Unexpected error: ${e.message}")
        e.printStackTrace()
        ExitCodes.GENERAL_ERROR
    }
}

// Test (in ApplicationTester)
val tester = ApplicationTester(::execute)  // ← Pass execute function reference
val exitCode = tester.runApplication("config.txt")  // ← Tests exception handling too
```

This enables **deep testing** - the entire application runs with fakes at the boundary. All three stages (Bootstrap → Manifest Building → Application) execute with fake dependencies, testing the full integration without mocking internal collaborators.

The pattern tests both the happy path (runApplication) and exception handling (execute) since ApplicationTester calls execute().

### Kotlin Full Application Test with Coroutines

For applications using coroutines, the ApplicationTester pattern adapts to use `suspend` functions and `runBlocking`:

```kotlin
class ApplicationTester(
    private val applicationRunner: suspend (Integrations) -> Int  // ← suspend function
) {
    private val fakeFileContents = mutableMapOf<String, List<String>>()
    private val fakeBinaryFiles = mutableMapOf<String, ByteArray>()
    private val capturedOutput = mutableListOf<String>()
    private val retryIntervals = mutableListOf<Long>()
    private var fakeHttpClient: FakeHttpClient = FakeHttpClient()
    private var fakeClock: () -> Instant = { Instant.parse("2024-01-15T10:30:00Z") }

    // Setup methods - same as blocking version
    fun setupConfigFile(
        fileName: String,
        sourceDirectory: String,
        outputFormat: String,
        archiveServerUrl: String,
        maxRetries: Int = 3,
        retryDelayMillis: Long = 1000,
        bufferSize: Int = 8192
    ) {
        val lines = listOf(
            "source-directory=$sourceDirectory",
            "output-format=$outputFormat",
            "archive-server-url=$archiveServerUrl",
            "max-retries=$maxRetries",
            "retry-delay-millis=$retryDelayMillis",
            "buffer-size=$bufferSize"
        )
        fakeFileContents[fileName] = lines
    }

    fun setupSourceFile(fileName: String, content: String) {
        fakeBinaryFiles[fileName] = content.toByteArray()
    }

    fun setupHttpClient(timesToFailBeforeSuccess: Int) {
        fakeHttpClient = FakeHttpClient(timesToFailBeforeSuccess)
    }

    fun setClock(instant: Instant) {
        fakeClock = { instant }
    }

    // Action method - returns exit code
    fun runApplication(configFileName: String): Int {
        val fakeFiles = FakeFiles(fakeFileContents)
        fakeBinaryFiles.forEach { (fileName, content) ->
            fakeFiles.addBinaryFile(fileName, content)
        }

        val fakeMessageDigest = FakeMessageDigest()
        val exitCode = ExitCodeImpl()

        val testIntegrations: Integrations = TestIntegrations(
            commandLineArgs = arrayOf(configFileName),
            files = fakeFiles,
            messageDigest = fakeMessageDigest,
            httpClient = fakeHttpClient,
            delay = { millis -> retryIntervals.add(millis) },  // ← delay (suspend), not sleep
            clock = fakeClock,
            emitLine = { line -> capturedOutput.add(line) },
            exitCode = exitCode
        )

        return runBlocking {  // ← runBlocking bridges blocking to suspend world
            applicationRunner(testIntegrations)
        }
    }

    // Query methods - same as blocking version
    fun outputContains(text: String): Boolean {
        return capturedOutput.any { it.contains(text) }
    }

    fun getOutputLineCount(): Int = capturedOutput.size

    fun getRetryIntervals(): List<Long> = retryIntervals.toList()

    fun getUploadAttemptCount(): Int = fakeHttpClient.getAttemptCount()
}

// Test usage - identical to blocking version
@Test
fun `full application flow with coroutines`() {
    // given
    val tester = ApplicationTester(::execute)  // ← execute is suspend fun
    tester.setupConfigFile(
        fileName = "test-config.txt",
        sourceDirectory = "source",
        outputFormat = "JSON",
        archiveServerUrl = "https://archive.example.com/upload"
    )
    tester.setupSourceFile("source/file1.txt", "Hello, World!")
    tester.setupSourceFile("source/file2.txt", "Goodbye!")

    // when
    val exitCode = tester.runApplication("test-config.txt")

    // then
    assertEquals(0, exitCode)
    assertTrue(tester.outputContains("Upload successful"))
}
```

**Key Differences from Blocking Version:**

| Aspect | Blocking | Coroutines |
|--------|----------|------------|
| Constructor signature | `(Integrations) -> Int` | `suspend (Integrations) -> Int` |
| Sleep/Delay integration | `sleep: (Long) -> Unit` | `delay: suspend (Long) -> Unit` |
| runApplication implementation | Direct call: `applicationRunner(testIntegrations)` | Wrapped: `runBlocking { applicationRunner(testIntegrations) }` |
| Test usage | `ApplicationTester(::execute)` | `ApplicationTester(::execute)` (same!) |

The coroutines version uses `runBlocking` in ApplicationTester.runApplication() to bridge from the blocking test world to the suspend function world. From the test's perspective, the API is identical - only the internal implementation differs.

**Coroutines Production Code:**

```kotlin
// Entry point
fun main(args: Array<String>) {
    val integrations: Integrations = ProductionIntegrations(args)
    val exitCode = runBlocking {  // ← runBlocking at entry point
        execute(integrations)
    }
    exitProcess(exitCode)
}

// Exception handler - suspend function
suspend fun execute(integrations: Integrations): Int {
    return try {
        runApplication(integrations)
        ExitCodes.SUCCESS
    } catch (e: ApplicationException) {
        System.err.println("Error: ${e.message}")
        e.exitCode
    } catch (e: Exception) {
        System.err.println("Unexpected error: ${e.message}")
        e.printStackTrace()
        ExitCodes.GENERAL_ERROR
    }
}

// Happy path - suspend function
suspend fun runApplication(integrations: Integrations) {
    // All staging and work uses suspend functions
    val bootstrapDeps = BootstrapDependencies(integrations)
    val configuration = bootstrapDeps.bootstrap.loadConfiguration()  // suspend fun

    val manifestDeps = ManifestDependencies(integrations, configuration)
    val manifest = manifestDeps.manifestBuilder.buildManifest()  // suspend fun

    val appDeps = ApplicationDependencies(integrations, configuration, manifest)
    appDeps.manifestUploader.upload()  // suspend fun
}
```

### Kotlin Component Test

```kotlin
class CreateElectionPageTester(
    private val testScope: TestScope,
    private val authToken: String = "test-token",
    private val testId: String = "create-election-test"
) : AutoCloseable {
    private val fakeClient = FakeApiClient()
    private val testRoot = ComposeTestHelper.createTestRoot(testId)
    private var capturedElectionName: String? = null
    private var backCalled = false

    init {
        renderComposable(rootElementId = testId) {
            CreateElectionPage(
                apiClient = fakeClient,
                authToken = authToken,
                onElectionCreated = { name -> capturedElectionName = name },
                onBack = { backCalled = true },
                coroutineScope = testScope
            )
        }
    }

    // Setup methods
    fun setupCreateElectionSuccess(electionName: String) {
        fakeClient.createElectionResult = Result.success(electionName)
    }

    fun setupCreateElectionFailure(error: Exception) {
        fakeClient.createElectionResult = Result.failure(error)
    }

    // Action methods
    fun enterElectionName(name: String) {
        ComposeTestHelper.setInputByPlaceholder(testId, "Election Name", name)
    }

    fun clickCreateButton() {
        ComposeTestHelper.clickButtonByText(testId, "Create")
        testScope.advanceUntilIdle()
    }

    // Query methods
    fun createElectionCalls() = fakeClient.createElectionCalls
    fun capturedElectionName() = capturedElectionName
    fun wasBackCalled() = backCalled
    fun electionNameInputExists() = ComposeTestHelper.inputExistsByPlaceholder(testId, "Election Name")

    override fun close() {
        testRoot.close()
    }
}

// Test using orchestrator
@Test
fun createElectionButtonClickCreatesElection() = runTest {
    CreateElectionPageTester(this).use { tester ->
        // given
        tester.setupCreateElectionSuccess("Test Election")

        // when
        tester.enterElectionName("Test Election")
        tester.clickCreateButton()

        // then
        assertEquals(1, tester.createElectionCalls().size)
        assertEquals("test-token", tester.createElectionCalls()[0].authToken)
        assertEquals("Test Election", tester.createElectionCalls()[0].electionName)
        assertEquals("Test Election", tester.capturedElectionName())
    }
}
```

**What the Tester hides:**
- Compose rendering setup
- Test root management
- Coroutine scope management
- FakeApiClient setup
- ComposeTestHelper DOM manipulation

**What tests see:**
- `setupCreateElectionSuccess(name)`
- `enterElectionName(name)`
- `clickCreateButton()`
- `createElectionCalls()`

### Kotlin Integration Test (HTTP API)

```kotlin
class HttpApiTester(private val port: Int = 9876) : AutoCloseable {
    private val runner: ApplicationRunner
    private val httpClient: HttpClient
    private val json = Json { ignoreUnknownKeys = true }
    private val baseUrl = "http://localhost:$port"

    init {
        val integrations = TestIntegrations()
        val configuration = Configuration(
            port = port,
            databaseConfig = DatabaseConfig.InMemory
        )
        val appDeps = ApplicationDependencies(integrations, configuration)
        runner = appDeps.runner
        runner.startNonBlocking()
        httpClient = HttpClient.newBuilder().build()
        waitForServerReady()
    }

    // Domain-focused API methods
    fun registerUser(userName: String, email: String = "$userName@example.com", password: String = "password"): HttpResponse<String> {
        val body = """{"userName":"$userName","email":"$email","password":"$password"}"""
        return post("/register", body)
    }

    fun registerUserExpectSuccess(userName: String, email: String = "$userName@example.com", password: String = "password"): Tokens {
        val response = registerUser(userName, email, password)
        assertEquals(200, response.statusCode())
        return json.decodeFromString<Tokens>(response.body())
    }

    fun createElection(electionName: String, token: AccessToken): HttpResponse<String> {
        val body = """{"electionName":"$electionName"}"""
        return post("/election", body, token)
    }

    fun setCandidates(electionName: String, candidates: List<String>, token: AccessToken): HttpResponse<String> {
        val candidatesJson = candidates.joinToString(",") { "\"$it\"" }
        val body = """{"candidates":[$candidatesJson]}"""
        return put("/election/$electionName/candidates", body, token)
    }

    // ... more domain methods
}

// Test using orchestrator
@Test
fun `create election succeeds`() {
    val tokens = tester.registerUserExpectSuccess("alice")

    val response = tester.createElection("Best Language", tokens.accessToken)

    assertEquals(200, response.statusCode())
}
```

**What the Tester hides:**
- Server lifecycle (start/stop)
- HTTP request building
- JSON serialization
- Polling for server readiness
- URL construction
- Header management

**What tests see:**
- `registerUser(name, email, password)`
- `createElection(name, token)`
- `setCandidates(electionName, candidates, token)`

### Kotlin Workflow Test (Test DSL)

```kotlin
class TestContext {
    val database: TestDatabase
    val events: TestEventStore

    fun registerUser(name: String): TestUser { /* ... */ }
    fun registerUsers(vararg names: String): List<TestUser> { /* ... */ }
}

class TestUser(val name: String, private val context: TestContext) {
    fun createElection(name: String): TestElection { /* ... */ }
    fun castBallot(election: TestElection, vararg rankings: Pair<String, Int>) { /* ... */ }
}

class TestElection(val name: String, private val context: TestContext) {
    val candidates: List<String> get() = /* ... */
    val eligibleVoters: List<String> get() = /* ... */

    fun setCandidates(vararg candidates: String) { /* ... */ }
    fun setEligibleVoters(vararg voterNames: String) { /* ... */ }
    fun launch() { /* ... */ }
    fun finalize() { /* ... */ }
    fun tally(): Tally { /* ... */ }
}

// Test using DSL
@Test
fun `voters can cast ballots after launch`() {
    val testContext = TestContext()
    val (alice, bob, charlie) = testContext.registerUsers("alice", "bob", "charlie")

    val election = alice.createElection("Programming Language")
    election.setCandidates("Kotlin", "Rust", "Go")
    election.setEligibleVoters("bob", "charlie")
    election.launch()

    bob.castBallot(election, "Kotlin" to 1, "Rust" to 2, "Go" to 3)
    charlie.castBallot(election, "Rust" to 1, "Kotlin" to 2, "Go" to 3)

    val tally = election.tally()
    assertEquals(2, tally.ballots.size)
}
```

**What the Tester hides:**
- Database setup and teardown
- Event store setup
- Domain object construction
- Service layer calls
- All infrastructure

**What tests see:**
- `registerUsers(names...)`
- `alice.createElection(name)`
- `election.setCandidates(candidates...)`
- `bob.castBallot(election, rankings...)`

## Implementation Guidelines

### 1. Tester Class Structure

```
class Tester {
    // Private: Fake dependencies
    private val fakeBackend = FakeBackend()
    private val fakeNotifications = FakeNotifications()

    // Private: System under test
    private val systemUnderTest = SystemUnderTest(fakeBackend, fakeNotifications)

    // Public: Setup methods (configure fake behavior)
    fun setupBackendSuccess() { /* ... */ }
    fun setupBackendFailure() { /* ... */ }

    // Public: Action methods (represent user/system actions)
    fun clickButton() { /* ... */ }
    fun enterText(text: String) { /* ... */ }
    fun submitForm() { /* ... */ }

    // Public: Query methods (for assertions)
    fun getDisplayedText(): String { /* ... */ }
    fun getBackendCalls(): List<Call> { /* ... */ }
    fun wasNotificationSent(): Boolean { /* ... */ }
}
```

### 2. Method Naming Conventions

**Setup methods:** `setup*` or `configure*`
- `setupSuccess()`
- `setupFailure(error)`
- `configureBackendToReturn(result)`

**Action methods:** Imperative verbs (what the user/system does)
- `clickButton()`
- `enterText(text)`
- `selectOption(option)`
- `pressKey(key)`

**Query methods:** Question form or `get*`
- `isButtonEnabled()`
- `getDisplayedText()`
- `wasNotificationSent()`
- `getBackendCalls()`

### 3. Given-When-Then Structure

Tests should follow this structure:

```kotlin
@Test
fun `descriptive test name`() {
    // given - setup initial state
    val tester = createTester()
    tester.setupBackendSuccess()

    // when - perform action
    tester.clickButton()

    // then - assert outcomes
    assertEquals(expected, tester.getResult())
    assertTrue(tester.wasBackendCalled())
}
```

### 4. Hide All Infrastructure Details

The Tester should hide:
- Framework-specific setup (React rendering, Compose rendering, HTTP server lifecycle)
- Async handling (promises, coroutines, callbacks)
- DOM manipulation (querySelector, getByText, etc.)
- Serialization (JSON, XML, protobuf)
- Mock/stub creation
- Type conversions
- Low-level APIs

Tests should only see:
- Domain concepts
- User actions
- Observable outcomes

### 5. Expose Both Infrastructure and Domain Views

Sometimes you need to assert on:
- Infrastructure calls (was backend called? with what arguments?)
- Domain state (what's displayed? what's in database?)

The Tester can expose both:

```kotlin
class Tester {
    // Domain view
    fun getDisplayedElectionName(): String { /* ... */ }
    fun getVoterCount(): Int { /* ... */ }

    // Infrastructure view (for verification)
    fun getBackendCalls(): List<Call> { /* ... */ }
    fun getDatabaseQueries(): List<Query> { /* ... */ }
}
```

### 6. Make Test Assertions Human-Readable

The Tester's job is to present data in forms that make test assertions obvious to humans reading the test.

**❌ Opaque (Hard to Understand):**
```kotlin
@Test
fun `compute checksum`() {
    val tester = Tester(bufferSize = 3)
    tester.addFile("file.txt", "abcdefg")

    val results = tester.computeChecksums(".")

    // What does this hex string mean? Can't tell what was digested.
    assertEquals("64696765737420666f723a206162632c206465662c2067", results[0].checksum)
}
```

**✅ Readable (Obvious Intent):**
```kotlin
@Test
fun `compute checksum with buffer size 3`() {
    val tester = Tester(bufferSize = 3)
    tester.addFile("file.txt", "abcdefg")

    val results = tester.computeChecksums(".")

    // Clear! Shows content was split into "abc", "def", "g" chunks.
    assertEquals("digest for: abc, def, g", tester.checksumFor("file.txt"))
}
```

The Tester hides the hex decoding internally:

```kotlin
class Tester(private val bufferSize: Int) {
    private val messageDigest = MessageDigestStub()
    private val checksumComputer = ChecksumComputer(messageDigest, bufferSize)
    private var results: List<FileChecksum> = emptyList()

    fun computeChecksums(directory: String): List<FileChecksum> {
        results = checksumComputer.compute(directory)
        return results
    }

    // Public API - returns human-readable string
    fun checksumFor(filePath: String): String {
        val result = results.find { it.path == filePath }
            ?: throw IllegalArgumentException("No result for: $filePath")
        return decodeChecksum(result.checksum)  // Convert hex to readable
    }

    // Private - hide implementation detail
    private fun decodeChecksum(hexChecksum: String): String {
        return hexChecksum.chunked(2)
            .map { it.toInt(16).toByte() }
            .toByteArray()
            .toString(Charsets.UTF_8)
    }
}
```

**Key principles:**

1. **Convert opaque formats** - Hex strings → readable text, byte arrays → strings, timestamps → ISO format
2. **Show what matters** - If testing buffering, show the chunks: `"abc, def, g"`
3. **Hide conversions** - Decoding/encoding logic belongs in Tester, not test assertions
4. **Never expose internal stubs** - `tester.messageDigest.getUpdateCalls()` is wrong, use `tester.getUpdateCalls()`

**More examples:**

```kotlin
// ❌ Opaque - what's being tested?
assertEquals(listOf(0x61, 0x62, 0x63), tester.getRawBytes())

// ✅ Readable - clear the content is "abc"
assertEquals("abc", tester.getContent())

// ❌ Breaks encapsulation - exposes internal stub
assertEquals(expected, tester.messageDigest.getUpdateCalls())

// ✅ Encapsulated - Tester provides clean API
assertEquals(expected, tester.getUpdateCalls())

// ❌ Opaque - timestamp as millis
assertEquals(1609459200000L, tester.getEventTimestamp())

// ✅ Readable - timestamp as ISO string
assertEquals("2021-01-01T00:00:00Z", tester.getEventTimestamp())
```

The goal: **A human reading the test should immediately understand what's being verified** without needing to decode hex, interpret raw bytes, or understand implementation details.

## Relationship to Architectural Rules

This pattern is **orthogonal** to the architectural rules:

- **Coupling and Cohesion:** Tester class is cohesive (serves one test scenario)
- **Dependency Injection:** Tester injects fake dependencies into system under test
- **Event Systems:** Tester may expose events for verification
- **Abstraction Levels:** Tester provides high-level test API (tests don't mix with infrastructure)
- **Testing at Boundaries:** Tester enables testing at boundaries by swapping implementations

The pattern **supports** the architectural rules but is specifically about **test structure**, not system architecture.

## When to Use This Pattern

**Use Test Orchestrator when:**
- Tests have complex setup (multiple dependencies, infrastructure)
- Tests interact with UI (DOM manipulation, events)
- Tests make network calls (HTTP, WebSocket)
- Tests need to control time, randomness, or other non-deterministic behavior
- Multiple tests share similar setup
- Implementation details change frequently

**Skip Test Orchestrator when:**
- Testing pure functions (no dependencies, deterministic)
- Testing simple data transformations
- Setup is trivial (one line)
- Only one test exists for the scenario

## Testing Exit Codes

Test orchestrators should expose exit codes for verification, allowing tests to verify both success and error paths.

### Pattern

The test orchestrator's action method returns the exit code from `runApplication()`:

```kotlin
class ApplicationTester {
    private val fakeFileContents = mutableMapOf<String, List<String>>()
    private val capturedOutput = mutableListOf<String>()

    // Setup methods
    fun setupConfigFile(fileName: String, csvPath: String, columns: String, format: String) {
        val lines = listOf(
            "csv-path=$csvPath",
            "columns=$columns",
            "format=$format"
        )
        fakeFileContents[fileName] = lines
    }

    fun setupCsvFile(fileName: String, header: List<String>, rows: List<List<String>>) {
        val headerLine = header.joinToString(",")
        val dataLines = rows.map { row -> row.joinToString(",") }
        fakeFileContents[fileName] = listOf(headerLine) + dataLines
    }

    // Action method - returns exit code
    fun runApplication(configFileName: String): Int {
        val fakeFiles = FakeFiles(fakeFileContents)
        val exitCode = ExitCodeImpl()
        val testIntegrations: Integrations = TestIntegrations(
            commandLineArgs = arrayOf(configFileName),
            files = fakeFiles,
            emitLine = { line -> capturedOutput.add(line) },
            exitCode = exitCode
        )
        return runApplication(testIntegrations)  // Returns Int
    }

    // Query methods
    fun outputContains(text: String): Boolean {
        return capturedOutput.any { it.contains(text) }
    }
}
```

### Testing Success and Error Paths

```kotlin
@Test
fun `returns exit code 0 on success`() {
    val tester = ApplicationTester()
    tester.setupConfigFile("config.txt",
        csvPath = "data.csv",
        columns = "name,department",
        format = "TABLE")
    tester.setupCsvFile("data.csv",
        header = listOf("name", "age", "department"),
        rows = listOf(listOf("Alice", "28", "Engineering")))

    val exitCode = tester.runApplication("config.txt")

    assertEquals(0, exitCode)
    assertTrue(tester.outputContains("Alice"))
    assertTrue(tester.outputContains("Engineering"))
}

@Test
fun `returns exit code 1 when CSV is empty`() {
    val tester = ApplicationTester()
    tester.setupConfigFile("config.txt",
        csvPath = "empty.csv",
        columns = "name",
        format = "TABLE")
    tester.setupCsvFile("empty.csv",
        header = emptyList(),
        rows = emptyList())

    val exitCode = tester.runApplication("config.txt")

    assertEquals(1, exitCode)
    assertTrue(tester.outputContains("CSV file is empty"))
}

@Test
fun `returns exit code 2 when file not found`() {
    val tester = ApplicationTester()
    tester.setupConfigFile("config.txt",
        csvPath = "missing.csv",
        columns = "name",
        format = "TABLE")
    // Don't setup the CSV file

    val exitCode = tester.runApplication("config.txt")

    assertEquals(2, exitCode)
    assertTrue(tester.outputContains("file not found"))
}
```

### Benefits

1. **Tests verify success and error paths** - Can assert on specific exit codes
2. **Tests are self-contained** - Don't need to check process exit
3. **Tests document error conditions** - Exit codes show what errors are possible
4. **Orchestrator hides complexity** - Tests don't see ExitCodeImpl construction
5. **Exit code accessible** - Test orchestrator exposes it through return value

### Integration with Integrations Pattern

Exit code belongs in Integrations (not ApplicationDependencies) because:
- It's a boundary concern (process exit code → OS)
- Any stage can set it (Bootstrap, Schema, Application)
- Tests substitute entire Integrations, including exit code

```kotlin
// Production
fun main(args: Array<String>) {
    val integrations: Integrations = ProductionIntegrations(args)
    val exitCode = runApplication(integrations)
    System.exit(exitCode)
}

fun runApplication(integrations: Integrations): Int {
    // ... stages
    return integrations.exitCode.value
}

// Tests
val testIntegrations: Integrations = TestIntegrations(
    commandLineArgs = testArgs,
    files = fakeFiles,
    emitLine = { line -> capturedOutput.add(line) },
    exitCode = ExitCodeImpl()  // Test controls exit code
)
val exitCode = runApplication(testIntegrations)
assertEquals(expectedExitCode, exitCode)
```

## Anti-Patterns to Avoid

### ❌ Exposing Low-Level Details in Test

```kotlin
@Test
fun testAddProfile() {
    val backend = FakeBackend()
    val component = render(<Profile backend={backend} />)
    const input = component.getByPlaceholderText('new profile')
    userEvent.type(input, 'Alice')
    fireEvent.keyUp(input, {key: 'Enter'})

    expect(component.getByText('Alice')).toBeInTheDocument()
}
```

**Problem:** Test is coupled to implementation details (DOM queries, event handlers).

### ❌ Tester with Too Many Responsibilities

```kotlin
class MegaTester {
    fun testEverything() { /* ... */ }
    fun setupAllScenarios() { /* ... */ }
}
```

**Problem:** One Tester trying to do too much. Create focused Testers for each test scenario type.

### ❌ Tests Calling Infrastructure Directly

```kotlin
@Test
fun test() {
    val tester = createTester()

    // ❌ Don't bypass the Tester
    val component = tester.getComponent()
    userEvent.click(component.getByText('Submit'))

    // ✅ Use Tester's action methods
    tester.clickSubmitButton()
}
```

**Problem:** Defeats the purpose of the Tester. All interactions should go through Tester methods.

### ❌ Opaque Test Data and Exposed Internal Stubs

```kotlin
@Test
fun test() {
    val tester = Tester(bufferSize = 3)
    tester.addFile("file.txt", "abcdefg")

    val results = tester.computeChecksums(".")

    // ❌ Opaque - what does this hex mean?
    assertEquals("64696765737420666f723a206162632c206465662c2067", results[0].checksum)

    // ❌ Breaks encapsulation - exposes internal stub
    assertEquals(listOf("ab", "cd", "e"), tester.messageDigest.getUpdateCalls())
}
```

**Problems:**
1. **Opaque assertions:** Hex string is unreadable - can't tell what's being tested
2. **Exposed internal stubs:** `tester.messageDigest` leaks implementation details

**✅ Fix with readable data and proper encapsulation:**

```kotlin
@Test
fun test() {
    val tester = Tester(bufferSize = 3)
    tester.addFile("file.txt", "abcdefg")

    val results = tester.computeChecksums(".")

    // ✅ Readable - shows buffering split content into chunks
    assertEquals("digest for: abc, def, g", tester.checksumFor("file.txt"))

    // ✅ Encapsulated - Tester provides clean API
    assertEquals(listOf("ab", "cd", "e"), tester.getUpdateCalls())
}
```

**Solution:** Tester converts opaque formats (hex, bytes) to readable strings and exposes methods that hide internal stubs.

## Summary

The Test Orchestrator Pattern creates readable, maintainable tests by:
1. **Hiding infrastructure complexity** behind a clean API
2. **Exposing domain-focused methods** for actions and queries
3. **Making test assertions obvious** - humans can immediately understand what's being verified
4. **Making tests declarative** - they read like specifications
5. **Making tests resilient** - implementation changes don't break tests

This pattern is universal across languages (JavaScript, Java, Kotlin, Python, etc.) and test types (unit, integration, component, end-to-end).

**Key principles:**
- Tests should read like domain specifications, not technical implementation guides
- A human reading the test should immediately understand what's being verified without needing to decode hex, interpret raw bytes, or understand implementation details
