# Auth

- Clients send `Authorization: Bearer <accessToken>`; other services call the same endpoints with a service token.
- Sign in (`POST /sessions`, `201`) returns the session with `accessToken`, `refreshToken` and their expiry instants; sign up (`POST /users`, `201`) returns only the user.
- Refresh: `POST /sessions/refresh` with `{ refreshToken }`. Sign out: `DELETE /sessions/current`. List sessions: `GET /users/me/sessions`. Revoke one: `DELETE /sessions/:sessionId`.
- Secrets (passwords, tokens, reset codes) go in the request body, never in the path or query.

## 401

- Missing, invalid or expired credentials: access and refresh tokens, a wrong password at sign in, a bad webhook signature. Bearer endpoints also send `WWW-Authenticate: Bearer` (RFC 6750).
- A wrong current password on an authenticated call (`changePassword`) is `422` on `currentPassword`, never `401`, so clients do not sign the user out.

## Account existence

- Do not reveal whether an account exists: sign in returns the same `401` for an unknown email and a wrong password.
- `POST /passwordResets` always returns `202` with `result: null` and no `Location` (the only `202` that is not a job).
- Sign up or an email change to a taken email is `409`; this leak is accepted and rate-limited.
