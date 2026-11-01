---
name: clean-code
description: Clean code rules for any language — naming, conditions, loops, collections, functions, types. Use any time code is written or changed, whatever the language or stack.
---

# Clean Code

Language idioms, official style guides and project conventions win over these rules — apply the intent.
Examples are illustrative; write them in the casing of the current language.

## Naming

- Functions: `<verb><Object?>`. No vague verbs (`handle`, `process`, `do`, `manage`) without a specific purpose.
- Methods: don't repeat the owner's context — `user.save()`, not `user.saveUser()`.
- Types and classes: no vague names (`Manager`, `Helper`, `Data`, `Utils`). Names sharing a role share a suffix (`…Service`), and the file name matches it.
- Booleans: `is` / `has` / `can` / `should` prefix; positive form, no double negatives.
- A value used in one place stays a literal when the context makes its meaning clear (`@Max(100)`). Extract a named constant when it is reused or unclear, named by meaning (`MAX_RETRIES`, not `THREE`).
- Include units when scale is ambiguous: `timeoutMs`, `sizeBytes`.
- One term per concept across the codebase.
- Enum stored or serialized values are stable and match member names unless an external contract says otherwise.
- Files and folders: one casing style across the project; the role is visible in the name or location; keep framework-required suffixes as the framework expects.

## Conditions

- A key that selects a value or action → lookup table, not `switch` / `if` chain. Always define the fallback for a missing key.
- No nesting: no `if` inside `if`, no loop inside a loop, no `if` wrapping a loop body. Nest only when there is no flat form.
- Flatten with early exits: guard clauses with `return` / error in functions, `continue` / `break` in loops; extract an inner loop or branch into a function.
- Main path stays flat: no `else` after `return`.
- Where the language has truthiness, check presence with it: `value`, `!value`, `!!value` — never compare with `undefined`, `null`, `true`, `false`. Where `0` / `''` are valid values, restructure (type check, `has`-style key check) instead of comparing.
- `switch` / `match`: no unintended fallthrough.

## Loops and collections

- Loop bodies only iterate and call; extract the processing into functions. Keep them flat with `continue`; `break` once further iterations are unnecessary.
- Never use callback-style iteration helpers for async work or when early exit is needed — use a loop.
- Run independent async operations concurrently; limit concurrency for large collections or constrained resources.
- Use find-first for the first match and any/all for boolean questions.
- Use reduce/fold only while it stays readable; otherwise a loop.
- Iterate a map/dictionary explicitly through its keys, values or entries.

## Functions

- Prefer one parameter object (or named/keyword arguments) over long positional parameter lists.
- No boolean parameters that switch between actions — split into separate functions.
- No wrappers: no pass-through methods, one-use aliases or interfaces, duplicated setup — call the target directly.
- Don't mutate inputs; if mutation is required, make it visible in the name or signature.
- Inside a function, separate logical blocks with one blank line: guards, data loading, computation, writes, `return`.

## Types

Where the language has types, hints or schemas:

- **Name every data shape you write out that crosses a boundary** — parameter, field, message, API body, error. NEVER write an anonymous inline structure there: define the shape once under a name and reference that name. Applies to code, plans and examples alike. A one-off local value inside a function body is the only exception.
- A library type or a type the compiler infers is already named — don't redeclare it. Don't annotate what the compiler infers; declare a type only for public response shapes, multi-field inputs and reused subsets.
- Reuse existing types; don't duplicate definitions of the same concept.
- No `any`-style escape hatches. Untrusted data enters as unknown/raw and is validated before use.
- Derive related types from a base one (pick/omit/partial, composition) instead of copying fields.
- Separate a contract (interface/protocol/trait) from its implementation only when more than one implementation exists or is planned.

## Review checklist

```
- [ ] No vague names (handle, process, Manager, Helper, Data)
- [ ] Lookup tables have a fallback
- [ ] No nested if / loops; early return, continue or an extracted function instead
- [ ] No else after return
- [ ] No callback iteration over async work
- [ ] No boolean flag parameters
- [ ] No pass-through methods, one-use aliases, duplicated setup
- [ ] No any / unvalidated external data
- [ ] No duplicated type definitions
- [ ] No anonymous inline structures in signatures, fields or API bodies
- [ ] No redeclared library or inferred types
- [ ] No comparison with undefined / null / true / false
- [ ] Blank line between logical blocks
```
