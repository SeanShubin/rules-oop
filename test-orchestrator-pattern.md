# Test Orchestrator Pattern

**Category:** Testing Practice
**Status:** Guideline (not prioritized with architectural rules)

## Concept

Tests should use a **Test Orchestrator** (often called "Tester") that hides infrastructure complexity and exposes a domain-focused, declarative API for interacting with the system under test. This makes tests readable, maintainable, and resilient to implementation changes.

## The Pattern

### Structure

1. **Create fake/stub dependencies** that provide controllable behavior
2. **Create a Tester class** that:
   - Constructs the system under test with fake dependencies
   - Hides all infrastructure complexity (DOM manipulation, HTTP, JSON serialization, async handling)
   - Exposes **setup methods** for configuring fake behavior
   - Exposes **action methods** representing user/system actions
   - Exposes **query methods** for making assertions
3. **Tests use the Tester** in given-when-then style
4. **Tests read declaratively** without low-level implementation details

### Benefits

- **Tests are readable:** Domain language, not technical details
- **Tests are resilient:** Implementation changes don't break tests (only Tester needs updating)
- **Tests are maintainable:** Common setup logic is in one place
- **Tests document behavior:** Reading tests shows what the system does
- **Refactoring is safe:** Change implementation, tests still pass

## Examples

### React Component Test (JavaScript)

```javascript
// Test Orchestrator
const createTester = async ({listProfilesResults}) => {
    const backend = createBackend({listProfilesResults})
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

    // Return orchestrator interface
    return {
        clickDeleteButton,
        typeProfileName,
        pressKey,
        backend,
        updateSummary,
        rendered
    }
}

// Test using orchestrator
test('add profile', async () => {
    // given
    const sample = createSample()
    const profile = sample.profile()
    const profilesBefore = []
    const profilesAfter = [profile]
    const tester = await createTester({
        listProfilesResults: [profilesBefore, profilesAfter]
    })

    // when
    await tester.typeProfileName(profile.name)
    await tester.pressKey('Enter')

    // then
    expect(tester.rendered.getByText(profile.name)).toBeInTheDocument()
    expect(tester.backend.addProfile.mock.calls).toEqual([[profile.name]])
    expect(tester.updateSummary.mock.calls.length).toEqual(1)
});
```

**What the Tester hides:**
- React rendering setup
- Context providers
- DOM queries (getByPlaceholderText, getByLabelText)
- Async handling (act)
- Mock setup

**What tests see:**
- `typeProfileName(name)`
- `pressKey(key)`
- `clickDeleteButton(id)`

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

## Summary

The Test Orchestrator Pattern creates readable, maintainable tests by:
1. **Hiding infrastructure complexity** behind a clean API
2. **Exposing domain-focused methods** for actions and queries
3. **Making tests declarative** - they read like specifications
4. **Making tests resilient** - implementation changes don't break tests

This pattern is universal across languages (JavaScript, Java, Kotlin, Python, etc.) and test types (unit, integration, component, end-to-end).

**Key principle:** Tests should read like domain specifications, not technical implementation guides.
