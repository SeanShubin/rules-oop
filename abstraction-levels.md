# Abstraction Levels

## Concept
Code at different levels of abstraction should be separated into distinct methods and classes. Higher-level code orchestrates by delegating to lower-level code, without knowing implementation details. Mixing orchestration with mechanics makes code harder to understand and change, because modifications to low-level details force changes to high-level coordination.

## Implementation
- Separate orchestration from mechanics:
    - High-level methods coordinate by calling lower-level methods
    - High-level methods don't contain implementation details
    - Low-level methods implement specifics without orchestrating
- Recognize levels through delegation structure:
    - If method A calls method B, A is at a higher level than B
    - The call hierarchy reveals the abstraction hierarchy objectively
- At class level:
    - Classes that orchestrate domain operations are at a higher level
    - Classes that implement data access mechanics are at a lower level
    - Classes that implement specific algorithms are at a lower level
    - These exist within domain packages, not in technical layer packages
    - Example: `payments.PaymentService` orchestrates, `payments.PaymentRepository` implements access
- At method level:
    - Extract implementation details into named helper methods
    - Keep orchestrating methods focused on coordination
    - Stop extracting when further splitting breaks cohesion

## Exceptions

These patterns are NOT violations:

- **Necessary type operations in heterogeneous collections**: Casting when working with `Map<K, Any>` or similar structures where type heterogeneity is the domain reality. The type system cannot express the constraints, so runtime checks are unavoidable.

- **Private cohesive helpers**: Helper methods that are private and serve only the class's primary responsibility (e.g., `hexFormat()` in a Formatter class, `sanitizeString()` in a StringProcessor). These are implementation details appropriately scoped to the class.

- **Interface convenience methods**: Default methods in interfaces that provide useful abstractions over raw data (e.g., `lookupByIndex()` that combines `get()` and `cast()`). These reduce duplication and make the interface more usable.

- **Inherent domain complexity**: When the domain itself requires type dispatch (parsers, visitors, dynamic data structures), the type checking IS the domain logic, not incidental mechanics. A JSON parser checking if a value is a Map, List, String, etc. is doing domain work.

**Test:** Ask "If I extract this, does it reduce complexity or just move it?" If extraction creates a new abstraction with no clear responsibility, or forces artificial naming ("getAndCast", "doTypeCheck"), leave it inline. Extraction should reveal intent, not obscure it.

## Examples of Genuine Violations vs. Acceptable Patterns

### ❌ VIOLATION: Business orchestration mixed with string parsing
```java
public void processOrder(String orderData) {
    // High-level: process order
    String[] parts = orderData.split(",");        // LOW-LEVEL DETAIL
    String id = parts[0].trim();                  // LOW-LEVEL DETAIL
    int quantity = Integer.parseInt(parts[1]);    // LOW-LEVEL DETAIL

    Order order = repository.find(id);
    order.updateQuantity(quantity);
    order.save();
}
```

**Why this is bad:** High-level orchestration (find order, update, save) is buried in low-level string parsing mechanics. If the format changes to JSON, you must modify the orchestration method.

**Fix:** Extract parsing to named method
```java
public void processOrder(String orderData) {
    OrderRequest request = parseOrderData(orderData);
    Order order = repository.find(request.id());
    order.updateQuantity(request.quantity());
    order.save();
}

private OrderRequest parseOrderData(String data) {
    String[] parts = data.split(",");
    return new OrderRequest(parts[0].trim(), Integer.parseInt(parts[1]));
}
```

**Why this is better:** Orchestration is clear and stable. Format changes are isolated to `parseOrderData()`.

### ❌ VIOLATION: Algorithm mixing coordination with bit manipulation
```java
public int calculateChecksum(byte[] data) {
    int checksum = 0;
    for (int i = 0; i < data.length; i++) {
        checksum += data[i] & 0xFF;              // LOW-LEVEL DETAIL
        if ((i & 1) == 0) {                      // LOW-LEVEL DETAIL
            checksum = (checksum << 1) | (checksum >>> 31);  // LOW-LEVEL DETAIL
        }
    }
    return applyFinalTransform(checksum);
}
```

**Fix:** Extract bit operations
```java
public int calculateChecksum(byte[] data) {
    int checksum = 0;
    for (int i = 0; i < data.length; i++) {
        checksum = addByteToChecksum(checksum, data[i]);
        if (isEvenIndex(i)) {
            checksum = rotateLeft(checksum);
        }
    }
    return applyFinalTransform(checksum);
}

private int addByteToChecksum(int checksum, byte b) {
    return checksum + (b & 0xFF);
}

private boolean isEvenIndex(int i) {
    return (i & 1) == 0;
}

private int rotateLeft(int value) {
    return (value << 1) | (value >>> 31);
}
```

### ✅ ACCEPTABLE: Type operations in heterogeneous collection
```java
interface JvmClass {
    Map<UShort, JvmConstant> constants();

    // This is fine - convenience over heterogeneous data
    default String lookupClassName(UShort index) {
        JvmConstant constant = constants().get(index);
        return ((JvmConstantClass) constant).name();
    }
}
```

**Why acceptable:** The constants map is heterogeneous by design (JVM spec requirement). The interface provides a useful abstraction that callers need. Extracting this to a separate "ClassNameLookupHelper" wouldn't reduce complexity, it would just move the cast to another class with no clear responsibility. The cast is necessary mechanics, not avoidable detail.

### ✅ ACCEPTABLE: Private formatting helpers
```java
class ReportFormatter {
    public List<String> formatReport(Report report) {
        return List.of(
            formatHeader(report),
            formatBody(report),
            formatFooter(report)
        );
    }

    private String formatHeader(Report report) {
        return "=".repeat(50) + "\n" + report.title().toUpperCase() + "\n";
    }

    private String formatBody(Report report) {
        return report.sections().stream()
            .map(this::formatSection)
            .collect(Collectors.joining("\n\n"));
    }

    private String formatFooter(Report report) {
        return "\n" + formatTimestamp(report.createdAt());
    }

    private String formatSection(Section section) {
        return section.title() + "\n" + "-".repeat(section.title().length()) +
               "\n" + section.content();
    }

    private String formatTimestamp(Instant timestamp) {
        return "Generated: " + DateTimeFormatter.ISO_INSTANT.format(timestamp);
    }
}
```

**Why acceptable:** All helpers are private and serve the class's single responsibility (formatting reports). The orchestration method `formatReport()` is clear. The helpers contain formatting details appropriately scoped to the class. They're not public utilities that need their own class.

### ✅ ACCEPTABLE: Domain complexity in visitor
```java
class JsonSerializer {
    public String serialize(Object value) {
        if (value == null) {
            return "null";
        } else if (value instanceof String) {
            return serializeString((String) value);
        } else if (value instanceof Number) {
            return value.toString();
        } else if (value instanceof Boolean) {
            return value.toString();
        } else if (value instanceof List) {
            return serializeList((List<?>) value);
        } else if (value instanceof Map) {
            return serializeMap((Map<?, ?>) value);
        } else {
            throw new IllegalArgumentException("Cannot serialize: " + value.getClass());
        }
    }

    private String serializeList(List<?> list) {
        return list.stream()
            .map(this::serialize)
            .collect(Collectors.joining(", ", "[", "]"));
    }

    private String serializeMap(Map<?, ?> map) {
        return map.entrySet().stream()
            .map(e -> serializeString(e.getKey().toString()) + ": " + serialize(e.getValue()))
            .collect(Collectors.joining(", ", "{", "}"));
    }

    private String serializeString(String s) {
        return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }
}
```

**Why acceptable:** Type checking is the domain logic here. JSON serialization inherently requires runtime type dispatch because Java's type system can't express "any JSON value". This isn't mixing levels - it's implementing the type dispatch that is the core algorithm. Extracting the type checks wouldn't simplify anything.

## Rationale

"Why separate levels?" Consider `processOrder` inlined with all parsing, database access, and validation logic mixed together. If the input format changes from CSV to JSON, you must modify the business logic method. When separated by levels, you change `parseOrderData()` in one place. The orchestration layer never needs to change.

"How do I know what level something belongs at?" Follow the delegation. If a method calls other methods, it's higher level than those methods. If a method contains implementation details (string splitting, arithmetic, parsing), it's low level. The structure reveals itself through what calls what.

"When do I stop extracting?" When further splitting breaks cohesion or creates abstractions with no clear responsibility. The goal is clarity, not maximum method count. If extraction would create a helper like `getAndCast()` or `checkTypeAndConvert()`, you've gone too far - those aren't useful abstractions, they're just displaced details.

"Doesn't this create too many small methods?" Only if you extract unnecessarily. Extract when you're mixing levels (orchestration with details), not when you're implementing a cohesive operation at one level. For example, CRUD operations (read, insert, update, delete) are all at the same level of abstraction - they're data access operations. Keep them together in one class rather than splitting each into its own class.

"What if my method is naturally complex?" Complexity at a single level is fine. A method with 30 lines of parsing logic operating at one level is clearer than a method mixing 3 lines of orchestration with 10 lines of parsing with 5 lines of formatting. Length matters less than consistent abstraction level.

"What about type checks in inherently dynamic code?" Type checks aren't always low-level details. In parsers, serializers, visitors, and dynamic data structures, type checking IS the algorithm. The key question: are you checking types to implement your domain logic, or are you checking types because your abstraction leaked? If removing the type check would require changing your interface, it's domain logic. If you could eliminate it with better types, it's leaking abstraction.

## Pushback

This rule assumes that vertical layering aids understanding more than it costs in indirection. It values being able to understand high-level flow without implementation details over seeing all code in one place. It assumes you'll modify implementation details more often than you'll change coordination patterns.

You might reject this rule if you believe seeing all code together aids comprehension more than separation. You might disagree if jumping between methods is more disruptive to your thinking than reading mixed levels. You might prefer flat structure if you work in domains where orchestration and mechanics are inherently intertwined (DSLs, query builders, fluent APIs). You might favor fewer methods if navigation overhead outweighs the benefit of separation.
