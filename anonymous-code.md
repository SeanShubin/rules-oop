# Anonymous Code

## Concept
The intent of logic is easier to understand when it has a name. When code appears inline without a name describing its purpose, readers must mentally parse the mechanics to infer the intent. Named functions, variables, and methods make intent explicit, reducing cognitive load and making the code self-documenting.

## Implementation
- No expressions with operators in parameter lists:
    - Property access is fine: `processUser(user.name)` - the property name provides context
    - Function calls are fine: `calculate(getTotal())` - the function name provides context
    - Literals need names: `calculate(5)` should be `val timeout = 5; calculate(timeout)` - literals lack context
    - Expressions with operators are not: `calculate(x + 5)` should be `val total = x + 5; calculate(total)`
- No mixed levels of abstraction in methods:
    - Each method should operate at a single level of detail
    - High-level orchestration should not mix with low-level mechanics
    - Split methods when abstraction levels mix, giving each fragment a descriptive name
- Never use a comment to explain what code does - use a well-named function or variable instead
- Comments are appropriate only to point to external references explaining why a decision was made
- Trailing lambda exception: languages with trailing lambda syntax may use simple inline predicates
    - `list.filter { it > 5 }` is acceptable
    - Complex lambdas should still be extracted and named

## Rationale
"Doesn't extracting everything create clutter?" Yes, if you extract operations where the mechanics ARE the intent. `calculate(getTotal())` is clear - calling `getTotal()` already has a name. But `calculate(x + 5)` hides intent - why are we adding 5? If it's tax, name it: `val priceWithTax = x + taxAmount; calculate(priceWithTax)`. The variable name documents the domain meaning, not just the mechanical operation.

"What about literal values?" Literals like `5` or `"admin"` have no inherent meaning. `calculate(5)` - is that seconds? retries? a threshold? The number itself doesn't tell you. Name it: `val timeoutSeconds = 5; calculate(timeoutSeconds)`. Now the intent is clear. Property access like `user.name` and function calls like `getTotal()` already have names that provide context, but raw literals don't. The only exception might be universally obvious literals like `0` or `1` in pure mathematical contexts, but even then, naming rarely hurts.

"What about obvious operations?" If an operation is so obvious that any developer would immediately understand its purpose without thinking, it might be fine inline. But "obvious" is context-dependent. `x + y` in a `sum()` function is obvious. `x + y` buried in business logic requires thought to understand its purpose. When in doubt, name it.

"Why is mixing abstraction levels bad?" Consider a method that validates a user, queries a database, parses JSON, and sends an email. Reading it requires jumping between "what is this doing?" (high level) and "how does this JSON parsing work?" (low level). Splitting into `validateUser()`, `findUserInDatabase()`, `parseUserJson()`, and `sendWelcomeEmail()` lets you read at one level and drill down only when needed.

"Why allow trailing lambdas?" Trailing lambda syntax exists specifically to make predicates and simple transformations readable. `users.filter { it.isActive }` reads naturally as "filter users by active status." The lambda is short, the intent is clear from context, and extracting it adds ceremony without clarity. However, `users.filter { user -> /* 10 lines of complex logic */ }` should be extracted: `users.filter(isEligibleUser)`.

"Why ban comments that explain what code does?" If you need a comment to explain what code does, the code isn't self-explanatory. Extract it to a named function instead. `// calculate tax` followed by `x * 0.08` should be `calculateTax(x)`. Comments explaining why ("using quick sort here because input is nearly sorted") remain valuable.

## Pushback
This rule assumes that explicit naming is worth the verbosity, and that clarity for readers outweighs brevity for writers. It values making intent obvious over keeping code compact. It assumes developers spend more time reading code than writing it, so optimizing for readability over write-time convenience is worthwhile.

You might reject this rule if you value conciseness over explicitness, working in a context where terseness is idiomatic (APL, code golf, mathematical proofs). You might disagree if you believe skilled developers should be able to parse complex expressions inline without help. You might prefer inline code if you think naming introduces more noise than signal, or if you work in a domain where the mechanics ARE the intent (compilers, parsers, mathematical algorithms). You might favor brevity if you believe too many small functions fragment code and make it harder to understand the whole.
