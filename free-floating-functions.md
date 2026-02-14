# Free Floating Functions

## Concept
File trees display filenames, not the functions inside them. When functions exist at the top level of files, developers cannot discover what functions exist without opening each file. This leads to accidental duplication when creating functions that already exist elsewhere, and makes code difficult to navigate because function calls provide no indication of their origin.

## Implementation
- Wrap public functions in classes, objects, or singletons to make them discoverable through namespacing
- Use language-appropriate containers:
    - Kotlin: companion objects (when functions relate to a specific class) or objects (standalone grouping)
    - Java: static methods in classes
    - TypeScript/JavaScript: exported objects or classes with static methods
    - Python: classes with @staticmethod or @classmethod
- Name the container to describe its responsibility (e.g., `DateHelpers`, `StringValidators`)
- The container name should match the filename
- Extension functions should be wrapped in containers as well
- Apply to all public top-level declarations: functions, constants, properties, type aliases
- Exceptions:
    - Private/file-scoped functions (not visible outside the file)
    - Files containing only a single public function

Example transformation:
```kotlin
// Before: DateUtils.kt
fun formatDate(date: Date): String = ...
fun parseDate(input: String): Date = ...
fun isValidDate(input: String): Boolean = ...

// After: DateHelpers.kt
object DateHelpers {
    fun format(date: Date): String = ...
    fun parse(input: String): Date = ...
    fun isValid(input: String): Boolean = ...
}

// Usage - provenance is clear
val formatted = DateHelpers.format(now)
```

## Rationale
"Don't modern IDEs solve this with autocomplete?" IDEs only help if you know the function exists and remember enough of its name to search for it. Browsing a namespace like `DateHelpers` shows all available date functions without prior knowledge.

"Aren't top-level functions idiomatic in my language?" Language idioms don't solve the discoverability problem. Even in languages that embrace top-level functions, wrapping them in containers makes the codebase easier to navigate and prevents duplication.

"What about truly generic utilities that don't belong to any domain?" These still need organization. A function like `max(a, b)` belongs in `MathUtils` or `Comparisons` or similar. The container name documents the function's category and makes it findable.

"Isn't this just creating artificial containers?" The container is not artificial - it serves the real purpose of making functions discoverable and preventing name collisions. Seeing `DateHelpers.format()` at a call site immediately tells you where to find the implementation. Seeing `format()` alone tells you nothing.

"How do I decide which container to use?" If the functions naturally extend or relate to a specific class's behavior, use a companion object or static methods on that class. If the functions form their own cohesive group independent of any single class, create a standalone container with a descriptive name.

"What about extension functions? Aren't they already namespaced by their receiver type?" While `String.isEmail()` indicates it operates on strings, it doesn't indicate which file contains the implementation. Wrapping in `StringExtensions` or similar makes the implementation discoverable through the file tree and groups related extensions together.

"Won't containers become dumping grounds like parent packages?" A container with too many unrelated functions signals a need to split into multiple containers with more specific responsibilities. This is no different from the problem of files with too many unrelated functions - the solution is the same: split them.

## Pushback
This rule assumes that discoverability through namespacing is worth the cost of wrapping functions in containers. It values being able to browse available functions and prevent accidental duplication over the simplicity of top-level functions. It assumes developers will create functions without knowing similar functions already exist, making explicit namespacing necessary.

You might reject this rule if you work in a small codebase where everyone knows what functions exist, making discoverability less critical. You might disagree if you believe IDE tools adequately solve the discovery problem and wrapping adds unnecessary ceremony. You might prefer top-level functions if you value language idioms over structural consistency, or if your team has strong conventions that prevent duplication without requiring containers. You might favor simplicity if you think the cost of navigating namespaces outweighs the benefit of explicit organization.
