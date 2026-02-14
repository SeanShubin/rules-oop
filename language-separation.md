# Language Separation

## Concept
Different languages should remain in their own contexts where their specialized tooling can function properly. When HTML, CSS, SQL, or other specialized languages are embedded as string literals in application code, you lose syntax highlighting, validation, refactoring support, and type safety. The separation strategy depends on the usage pattern: dynamic composition (HTML) benefits from structured representations, while static declarations (CSS, SQL) belong in resource files. Keeping each language in its proper environment - application code for logic, structured representations for dynamic generation, resource files for static content - maintains clear separation of concerns and enables full tool support for each language.

## Implementation

### Application Code
- Never embed HTML or CSS as string literals in application code (except for runtime-calculated values - see Exceptions below)
- Use structured representations for dynamic markup generation
- Load static resources via appropriate mechanisms (classloader, file system, bundler)
- Keep application logic focused on behavior, not presentation syntax

### HTML (Dynamic Structure)
HTML is generated dynamically with conditionals, loops, and data-driven structure. Use structured representations:
- Define `HtmlElement` interface with `Tag` and `Text` implementations
- Build through composition: `Tag("div", children = listOf(Tag("p", Text("content"))))`
- Type-safe attributes: `Tag("a", attributes = listOf("href" to url))`
- Compose conditionally: `if (hasError) Tag("div", Text(error)) else emptyList()`
- Why structured? HTML has complex nested syntax that benefits from type safety and compositional patterns. The structure catches errors at compile time and makes nesting explicit.

### CSS (Static Rules)
CSS consists of static styling rules and dynamic class application. Separate these concerns:
- Store CSS rules in resource files: `src/main/resources/static-content/*.css`
- Load via classloader: `val css = resourceLoader.load("styles.css")`
- Apply classes as simple strings: `Tag("div", attributes = listOf("class" to "header"))`
- Conditional styling through class selection: `val className = if (hasError) "error" else "success"`
- Why resource files? CSS rules are static declarations with no complex composition. Class names are simple identifiers that don't need structured representation.
- Optional: Inline CSS by loading resource content into `<style>` tag for single-file deployment

### SQL (Static Queries)
SQL queries are static declarations with parameter placeholders. Store them in resource files:
- Store each query in its own file: `src/main/resources/database/user-select-by-email.sql`
- Load via classloader: `val query = queryLoader.load("user-select-by-email")`
- Use with prepared statements: `preparedStatement = connection.prepareStatement(query)`
- Parameter placeholders in SQL: `where email = ?` for JDBC-style binding
- Why resource files? SQL has complex syntax that loses validation, highlighting, and formatting in strings. One query per file aids discoverability.
- Why not structured? Unlike HTML's dynamic composition, SQL queries are static text with parameter substitution. The complexity is in the SQL language itself, not in how queries combine. Parameter binding is the only dynamic aspect, handled by the database driver.

### Static HTML (Templates, Redirects)
- Store complete HTML files in resource directories: `src/main/resources/static-content/*.html`
- Load when needed: `resourceLoader.load("redirect.html")`
- Use for content that doesn't require dynamic generation

## Exceptions

Sometimes mixing languages is unavoidable when values must be calculated at runtime:

### Acceptable: Runtime-Calculated CSS
When CSS values depend on runtime data that cannot be predetermined, inline styles are acceptable:
- **Progress bars**: `style="width: ${percentage}%"` - width calculated from data
- **Dynamic colors**: `style="background-color: ${user.themeColor}"` - user-specific colors
- **Calculated positions**: `style="top: ${yPosition}px; left: ${xPosition}px"` - layout from data
- **Data-driven sizing**: `style="height: ${itemCount * 20}px"` - dimensions based on content

### Test: Is This Truly Runtime?
Ask: "Could this value be determined when I write the code, or only when the code runs?"
- ✅ Progress percentage from database query - runtime only
- ✅ User's chosen theme color - runtime only
- ❌ Standard button styles - known at compile time, use CSS class
- ❌ Responsive breakpoints - known at compile time, use media queries

### Pattern for Runtime CSS
When you must generate CSS at runtime:
- Keep it minimal - only the dynamic values
- Use inline styles on specific elements, not `<style>` blocks
- Reference CSS classes for static styling
- Example: `<div class="progress-bar" style="width: ${percent}%">` combines static class with dynamic value

## Rationale
"Why does HTML need structured representation but CSS and SQL don't?" HTML generation involves dynamic composition - conditionals, loops, data-driven structure. `Tag` objects compose naturally: `if (error) Tag("div", Text(error))`. CSS rules and SQL queries are static declarations - you write them once in resource files. The dynamic part happens differently: for CSS, you apply classes as strings (`"class" to "error"`); for SQL, you bind parameters (`statement.setString(1, email)`). The complexity patterns differ: HTML benefits from compositional structure, while CSS and SQL benefit from staying in their native syntax where tooling can validate and format them.

"Why doesn't SQL need structured representation like HTML?" SQL queries are static text with parameter placeholders, not dynamically composed structures. You don't conditionally build query fragments the way you build HTML trees. Parameter substitution (the only dynamic aspect) is handled by prepared statements, which provide both safety and performance. Keeping SQL in `.sql` files maintains syntax validation, formatting, and the ability to test queries independently. The query loader pattern is simpler than object composition and matches how SQL is actually used: load once, bind parameters, execute.

"What about CSS class names as magic strings?" CSS class names are identifiers, not complex syntax. Using `"error"` as a string is no different from using `"userId"` as a map key - it's a simple reference. The coupling is intentional and clear: code applies classes that CSS defines. If validation matters, use constants: `object CssClasses { const val ERROR = "error" }`, but plain strings are fine for straightforward cases. The class name is the contract between code and stylesheet.

"Doesn't this add complexity?" Yes, initially. But string literals lack structure - there's no validation, no IDE support for HTML syntax, and changes require careful quote escaping. Structured representations catch errors at compile time, support refactoring, and make the structure explicit. The complexity pays for itself when you need to modify the HTML or test the generation logic.

"What about simple HTML snippets?" Even simple HTML benefits from structure. A three-line string literal might seem fine, but when you need to add attributes, nest elements, or conditionally include content, string concatenation becomes unmaintainable. Starting with structure avoids refactoring later. The `Tag` approach scales from simple to complex without changing patterns.

"Why separate CSS and SQL from code entirely?" CSS and SQL in strings require escape sequences, lose syntax highlighting, and mix concerns. Resource files can be edited independently, validated by specialized tools, and tested in isolation. Storing CSS and SQL as resources maintains separation of concerns - code focuses on logic, resources focus on their specialized languages. Changes to styling or queries don't require code recompilation.

"What about the resource loading overhead?" Loading files from resources at startup is negligible compared to the maintenance cost of embedded strings. Resources are loaded once, cached in memory, and don't require recompilation when content changes. The pattern also enables environment-specific resources (different queries for different databases, different styles for different themes) without code changes.

"Isn't structured HTML more verbose?" Yes, but verbosity isn't the same as complexity. `Tag("div", Text("hello"))` is more characters than `"<div>hello</div>"`, but it's also type-safe, composable, and refactorable. The verbosity documents the structure explicitly rather than hiding it in string syntax. When you need to nest deeper or add conditionals, the structured approach remains clear while string concatenation becomes tangled.

## Examples

### Good: Structured HTML with Conditional Logic
```kotlin
// Example using Kotlin - pattern applies to any language
val statusClass = if (hasProblems) "has-problems" else "no-problems"
val section = Tag(
    "section",
    attributes = listOf("class" to statusClass),
    children = listOf(
        Tag("h2", Text(title)),
        Tag("p", Text(description))
    )
)
```

### Good: CSS in Resource File with Dynamic Class Application
```kotlin
// In application code (Kotlin example)
fun createUserCard(user: User): HtmlElement {
    val cardClass = if (user.isActive) "user-card active" else "user-card inactive"
    return Tag(
        "div",
        attributes = listOf("class" to cardClass),
        children = listOf(
            Tag("h3", Text(user.name)),
            Tag("p", Text(user.email))
        )
    )
}

// In resources/static-content/styles.css
.user-card {
    border: 1px solid #ccc;
    padding: 1em;
}

.user-card.active {
    border-color: green;
}

.user-card.inactive {
    border-color: red;
    opacity: 0.6;
}
```

### Good: Loading CSS from Resources
```kotlin
// Example using Kotlin - pattern applies to any language
class HtmlFormatter(private val resourceLoader: ResourceLoader) {
    private fun createHead(): HtmlElement {
        val styleCss = resourceLoader.load("styles.css")
        return Tag(
            "head",
            children = listOf(
                Tag("title", Text("Report")),
                Tag("style", Text(styleCss))
            )
        )
    }
}
```

### Good: Runtime-Calculated CSS (Progress Bar)
```typescript
// Example: TypeScript calculating progress bar width at runtime
function renderProgressBar(completed: number, total: number): string {
  const percentage = (completed / total) * 100;
  // Static styles in CSS, dynamic value inline
  return `<div class="progress-bar" style="width: ${percentage}%"></div>`;
}

// In styles.css (static styling)
.progress-bar {
  height: 20px;
  background-color: #4CAF50;
  transition: width 0.3s ease;
}
```

### Good: SQL in Resource Files with QueryLoader
```kotlin
// Example using Kotlin - pattern applies to any language
class QueryLoaderFromResource : QueryLoader {
    override fun load(name: String): String {
        val resourceName = "com/seanshubin/condorcet/backend/database/$name.sql"
        val classLoader = this.javaClass.classLoader
        val inputStream = classLoader.getResourceAsStream(resourceName)
        return inputStream.readText()
    }
}

// Usage in application code
class UserRepository(private val queryLoader: QueryLoader) {
    fun findByEmail(email: String): User? {
        val query = queryLoader.load("user-select-by-email")
        val statement = connection.prepareStatement(query)
        statement.setString(1, email)
        return statement.executeQuery().toUser()
    }
}

// In resources/database/user-select-by-email.sql
select name,
       email,
       salt,
       hash,
       role
from user
where email = ?
```

### Bad: HTML as String Literal
```kotlin
// DON'T: Mixing HTML syntax into application code
val html = "<div class='$statusClass'><h2>$title</h2><p>$description</p></div>"

// Problems:
// - No syntax checking for HTML
// - IDE doesn't recognize HTML structure
// - Error-prone quote escaping
// - String interpolation can break HTML
// - Refactoring tools won't find HTML elements
```

### Bad: CSS as String Literal
```python
# DON'T: Embedding static CSS in application code
css = """
.user-card { border: 1px solid #ccc; padding: 1em; }
.active { border-color: green; }
.inactive { border-color: red; opacity: 0.6; }
"""

# Problems:
# - No CSS syntax validation
# - No CSS tooling support
# - Changes require recompilation
# - Can't be cached separately by browsers
# - Designers can't edit without touching code
```

### Bad: SQL as String Literal
```java
// DON'T: Embedding SQL queries in application code
public User findByEmail(String email) {
    String query = "select name, email, salt, hash, role " +
                   "from user " +
                   "where email = ?";
    PreparedStatement statement = connection.prepareStatement(query);
    statement.setString(1, email);
    return statement.executeQuery().toUser();
}

// Problems:
// - No SQL syntax validation
// - No SQL formatting or highlighting
// - Query changes require recompilation
// - Hard to find all queries that touch a table
// - No tooling support for SQL refactoring
// - Can't easily test queries independently
```

### Bad: Complex HTML Concatenation
```javascript
// DON'T: Building HTML through string operations
const html = "<table>" +
    "<thead><tr>" +
    headers.map(h => `<th>${h}</th>`).join("") +
    "</tr></thead><tbody>" +
    rows.map(row =>
        "<tr>" + row.map(cell => `<td>${cell}</td>`).join("") + "</tr>"
    ).join("") +
    "</tbody></table>";

// Problems:
// - Difficult to verify structure is correct
// - Easy to miss closing tags
// - Hard to add attributes conditionally
// - Refactoring is error-prone
```

## Pushback
This rule assumes that language separation and tooling support outweigh the convenience of string literals. It values compile-time safety and maintainability over write-time simplicity. It assumes you benefit from IDE support, refactoring tools, and type safety more than from keeping everything in one language. It presumes that HTML/CSS generation happens frequently enough to justify structured representations and resource loading infrastructure.

You might reject this rule if you're generating trivial markup (e.g., a single `<br>` tag) where structure adds no value. You might prefer string literals if you're prototyping throwaway code that will be discarded. You might disagree if you work in a templating-focused framework where embedded markup is idiomatic and well-supported by tooling. You might favor simplicity over separation if your HTML is so basic that structured representations feel like over-engineering. You might prefer inline styles/markup if you're generating one-off diagnostic output or log messages that will never be maintained. You might reject language separation if you believe the cognitive overhead of switching between representations outweighs the tooling benefits.
