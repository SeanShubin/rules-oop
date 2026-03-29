---
name: validate-project
description: High-level code quality evaluation of entire codebase
---

# Validate Project

Perform a comprehensive architectural and code quality assessment of the entire codebase against the code quality rules.

## Approach

This command provides a **high-level architectural assessment**, not line-by-line validation. For focused validation of recent changes, use `/validate-changes` instead.

## Steps

1. **Analyze project structure:**
   - Identify programming languages used
   - Map out package/module hierarchy
   - Understand project organization

2. **Detect architectural patterns using Agent with Explore subagent:**
   - Package dependencies and potential cycles
   - Module boundaries and coupling patterns
   - Common architectural patterns (layers, components, etc.)

3. **Scan for systemic violations:**
   Use targeted searches to find common patterns:
   - **Cyclic dependencies**: Check import/dependency patterns
   - **Concrete dependencies**: Search for direct instantiation of infrastructure classes (databases, file systems, network clients)
   - **Mixed abstraction levels**: Look for large methods mixing orchestration with low-level details
   - **Global state access**: Search for `System.out`, `System.err`, `println`, global loggers
   - **Anonymous code**: Look for complex inline expressions in parameters
   - **Language mixing**: Check for embedded HTML/CSS in string literals

4. **Strategic sampling:**
   - Select representative files from each major component/package
   - Load and evaluate against the `code-quality:oop` skill rules
   - Look for patterns that indicate broader issues

5. **Report findings:**
   Organize by priority:

   ### Architectural Issues (Highest Priority)
   - Cyclic dependencies with example locations
   - Package hierarchy violations
   - Major coupling hotspots

   ### Systemic Patterns (High Priority)
   - Widespread concrete dependencies
   - Mixed abstraction levels across codebase
   - Global state access patterns

   ### Code Organization (Medium Priority)
   - Anonymous code patterns
   - Language separation issues
   - Free-floating functions

   For each issue:
   - Describe the pattern detected
   - Provide 2-3 example locations
   - Explain why it's problematic
   - Suggest general approach to fix

   ### Summary Statistics
   - Number of packages/modules analyzed
   - Files sampled
   - Major violation categories and counts

6. **Actionable next steps:**
   - Prioritized list of improvements
   - Suggested order for addressing issues
   - Note: "For detailed validation of specific changes, use `/validate-changes`"

## Notes

- This is a **summary-level assessment** suitable for understanding project health
- On very large projects (1000+ files), analysis may take several minutes
- The Explore agent will sample strategically rather than reading every file
- Focus is on **architectural and systemic issues**, not every individual violation
