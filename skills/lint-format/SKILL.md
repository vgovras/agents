---
name: lint-format
description: oxlint + oxfmt setup with custom rules (explicit comparisons, blank lines, enum style) and import boundaries between modules. Use any time a JS/TS project's lint or format setup is created or changed, a module is added (its import boundary override), or a lint error from these rules has to be fixed.
---

# Lint and format: oxlint + oxfmt

## Setup

- Dev dependencies: `oxlint`, `oxlint-tsgolint` (type-aware rules), `oxfmt` — latest versions (skill `dev-environment`).
- Copy [templates/.oxlintrc.json](templates/.oxlintrc.json), [templates/.oxfmtrc.json](templates/.oxfmtrc.json) and [templates/lint/](templates/lint/) (custom rule plugins + their specs) into the project root.
- Scripts: `"lint": "oxlint --deny-warnings"`, `"lint:fix": "oxlint --fix"`, `"fmt": "oxfmt"`, `"fmt:check": "oxfmt --check"`; include `lint/` in tsconfig `include`.
- Style is NestJS: single quotes, trailing commas, 2 spaces, 80 columns, sorted imports.

## Custom rules

| Rule | Enforces |
|---|---|
| `comparison/no-explicit-comparison` | no `===` / `!==` with `undefined`, `null`, `true`, `false` |
| `padding/blank-lines` | blank line after variable declarations, after a guard clause, before `return` (autofix) |
| `naming/enum-style` | enum name PascalCase, members and string values UPPER_SNAKE_CASE; `ErrorCode` values dotted lowerCamel keys |

Fix the code, not the rule. Unused disable comments are errors.

`eslint/no-magic-numbers` is off in DTOs, models, schemas and controllers: a one-place literal there is clear from its decorator or column (skill `clean-code` › Naming).

## Import boundaries

`eslint/no-restricted-imports` encodes skill `backend-module-structure`:

- everywhere: no `../`;
- other modules' private files: `dto/`, `schemas/`, `*.schema.js`, `*.controller.js` (actions may import schemas);
- `src/libs/**`: nothing from `modules/`, `actions/`, `common/`;
- `src/common/**`: nothing from `modules/`, `actions/`.

A pattern list in an override replaces the root one, so every module gets its own override that repeats the root patterns plus `!#src/modules/<module>/**` (its own private files stay importable). New module → copy the `<module>` override from the template.

## Checklist

```
- [ ] Configs and lint/ plugins copied, scripts added
- [ ] Every module has its import-boundary override
- [ ] make check clean
```
