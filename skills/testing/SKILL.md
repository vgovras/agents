---
name: testing
description: Use when writing, modifying, or reviewing tests (*.spec.ts, *.integrations-spec.ts, *.e2e-spec.ts) — choosing the test type, file location, mocking, test data, and isolation.
---

# Testing

## Choose the type

| Type | When | Mocks | File |
|---|---|---|---|
| Unit | Pure synchronous logic with exact input → output: math, parsing, mapping, data transformation | None, ever. Logic that needs a mock is not unit-testable — extract the pure part into a service with no dependencies (`<domain>-rules.service.ts`) or a `libs/` helper; never a `utils` file | `<name>.spec.ts` next to the tested file; instantiate with `new` |
| Integration | Logic that depends on an external provider (email, SMS, S3, payment, any vendor API) | Only the external provider, via its `I<Name>` token. Never the DB | `test/integrations/<name>.integrations-spec.ts` |
| E2E | The system works end to end: HTTP → modules → DB | None | `test/e2e/<name>.e2e-spec.ts` |

- Pick the cheapest type that proves the behavior. Never write a unit test that mocks; never mock what you can run.
- Integration and e2e tests hit the real Postgres.

## Rules

- **No duplication:** each behavior is tested once, at one level. Do not re-test in e2e what an integration test covers unless the wiring itself is the point. Shared setup goes into helpers, not copy-paste.
- **Deterministic:** same result on every run, in any order, in parallel. No real time (`vi.useFakeTimers()` / injected clock), no `Math.random`, no network outside the tested system, no reliance on execution order or on data created by another test.
- **Isolated data:** never delete, truncate, or update data you did not create in this test. Create unique data (`crypto.randomUUID()` in emails, names, keys) and assert only on it. Cleanup, if any, removes only your own rows by their ids.
- **Arrange–Act–Assert:** one behavior per `it`; the name states the expected outcome (`returns 404 when user is missing`).
- **Assert behavior, not implementation:** public API, HTTP responses, DB state — not private calls.
