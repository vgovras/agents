---
name: typescript
description: TypeScript rules — compiler settings, imports, type inference, type naming, enums, comparisons. Use any time TypeScript code or tsconfig is written or changed, whatever the framework.
---

# TypeScript

## Compiler

- `strict` plus every extra strictness flag (`noUncheckedIndexedAccess`, `noImplicitOverride`, `noImplicitReturns`, `noPropertyAccessFromIndexSignature`, `noUnusedLocals`, `noUnusedParameters`, `noFallthroughCasesInSwitch`, `noUncheckedSideEffectImports`, `verbatimModuleSyntax`, `isolatedModules`, `allowUnreachableCode: false`, `allowUnusedLabels: false`).
- Off: `strictPropertyInitialization` and `exactOptionalPropertyTypes`. So: never `field!: T`, never `field?: T | undefined` — write `field: T` and `field?: T`.
- ESM (`"type": "module"`, `module` / `moduleResolution`: `nodenext`).

## Imports

- Same folder: `./x.js` (with the `.js` extension). Anything else: `#src/...`. Never `../`.
- `#src/*` is a Node subpath import in `package.json` plus a matching tsconfig `paths` entry:
  ```json
  "imports": { "#src/*": { "development": "./src/*", "default": "./dist/*" } }
  ```
- Types only → `import type`.

## Types

- Don't annotate what TS infers: locals, private methods, service returns. Annotate only public response shapes and where lint requires it.
- Prefer library types and inference over new declarations: `ReturnType<X['method']>`, `Awaited<…>`, `typeof table.$inferSelect`.
- `*.types.ts` stays minimal: only public response shapes, multi-field service inputs and reused `Pick`s.
- Derive with `Pick` / `Omit` / `Partial` where it removes duplication.
- `I` prefix only on a type used in `implements` (`IWordRow`). No other type or interface has a prefix.

## Enums

- A set of values is a string `enum` in `enums/<name>.enum.ts` (`<name>.enum.ts` in the module root while it is the only one).
- Name PascalCase; members and values UPPER_SNAKE_CASE, value = member name:
  ```ts
  export enum <Name> {
    <MEMBER_A> = '<MEMBER_A>',
    <MEMBER_B> = '<MEMBER_B>',
  }
  ```
- Exception: `ErrorCode` values are dotted message keys (`'common.validation.required'`). Error codes are string keys, never numbers.

## Comparisons

- No `=== undefined`, `=== null`, `=== true`, `=== false` (or `!==`). Use `value`, `!value`, `!!value`.
- Where `0` / `''` are valid values, restructure: `typeof value === 'number'`, `map.has(key)`.

## Checklist

```
- [ ] No `!:`, no `?: T | undefined`
- [ ] Imports: ./x.js or #src/..., no ../, import type for types
- [ ] No annotations TS infers; no redeclared library types
- [ ] I prefix only for implements
- [ ] Enums: string, PascalCase, UPPER_SNAKE_CASE members = values (ErrorCode: dotted keys)
- [ ] No comparison with undefined / null / true / false
```
