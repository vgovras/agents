---
name: rest-api-design
description: Use when designing, adding, or reviewing REST endpoints or controllers — choosing paths, HTTP methods, params, request/response shapes, pagination, errors, async jobs, uploads, webhooks, or API versioning.
---

# REST API Design

Resource-oriented design ([AIP-121](https://google.aip.dev/121)) with custom methods for non-CRUD operations ([AIP-136](https://google.aip.dev/136)), on HTTP semantics of [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110). See also [Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines) and [Zalando RESTful API Guidelines](https://opensource.zalando.com/restful-api-guidelines/).

Everything is `camelCase`: paths, path params, query params, JSON fields, multipart field names.

## Resources and paths

- Resources are plural nouns. Item paths are flat, so names are global: use the plain name when it is unambiguous across the API (`comments`). When several owners have children of the same kind, prefix all of them with their owner (`orderItems`, `cartItems`); renaming a published resource is breaking, so generic words (`items`, `sections`, `types`, `transfers`, `settings`, `entries`) are always prefixed (`seatingSections`, `ticketTransfers`). Join resources have no flat path and keep plain names (`members`).
- List and create are nested under the owner; operations on one item use its flat path:
  - `GET /folders/:folderId/documents`, `POST /folders/:folderId/documents`;
  - `GET /documents/:documentId`, `PATCH /documents/:documentId`, `DELETE /documents/:documentId`.
  Top-level resources have no owner: `GET /workspaces`. A path has at most one parent collection.
- The owner is the resource the item belongs to in its lifecycle: the side a client operation targets (a reservation belongs to its restaurant), or the resource that produced it (an invoice belongs to its subscription). Resources created before their owner is known are top-level (`POST /sessions` at sign in).
- Extra lists, all limited to what the caller may see:
  - from an ancestor: `GET /workspaces/:workspaceId/documents`;
  - from the other side of a relation: `GET /users/me/reservations`, `GET /users/me/invoices`;
  - across all owners, at the top level with filters: `GET /messages?query=…&channelId=…`;
  - of related items of the same type: `GET /messages/:messageId/replies` returns messages; `POST` to it creates one, with `Location` at `/messages/:messageId`.
- Join resources (membership, reaction, pin) link a parent to something with a public, URL-safe key and have no id of their own. They live only at `/<parents>/:parentId/<joins>/:key`:
  - `GET /channels/:channelId/members` lists, `PUT /channels/:channelId/members/:userId` adds or updates (body: the join's fields, e.g. `{ role }`), `DELETE` removes;
  - keys are identifiers, never raw Unicode or secrets: `PUT /messages/:messageId/reactions/thumbsUp`, `PUT /channels/:channelId/pins/:messageId`. Applying a coupon code is a create with the code in the body: `POST /subscriptions/:subscriptionId/discounts`.
- A singleton is a singular noun that exists exactly once per owner and is part of the owner's path (it does not count as a parent):
  - `GET` always returns `200` with the full object (unset fields `null`, lists `[]`); `PUT` replaces it, `PATCH` updates it, `DELETE` resets it to empty; no `POST`;
  - its children nest under it: `POST /users/me/cart/cartItems`, then `PATCH /cartItems/:cartItemId`;
  - it may be per caller when the owner is shared: `GET /channels/:channelId/readState`; owner list items embed it (`channel.readState`) so clients do not fetch it per owner;
  - a file attached to an existing resource is a singleton uploaded with multipart `PUT`: `PUT /users/me/avatar`;
  - name it as a noun phrase when the concept is plural: `openingSchedule`.
  Use a collection instead when instances have history or are created by a paid action (subscriptions: `GET /users/me/subscriptions?status=active`).
- Computed read-only views use singleton paths, support only `GET`, and take their inputs as query params: `GET /restaurants/:restaurantId/availability?date=…&partySize=…`. A preview of a write is such a view: `GET /subscriptions/:subscriptionId/prorationPreview?planId=…`. When the inputs do not fit in query params (a cart of items), the preview is `POST` to the write's path plus `/preview` with the same body as the write: `POST /restaurants/:restaurantId/orders/preview`, `200`, creates nothing.
- A grouping without its own id (a restaurant's waiting list for a day) is not a resource: list its members with a required filter (`GET /restaurants/:restaurantId/waitlistEntries?date=2026-10-24`, missing `date` is `422`).
- Pseudo-ids for the caller: `me` for `:userId`, `current` for `:sessionId`.
- Roles share the same paths. If the caller cannot read the target, it is `404`; if they can read it but their role may not perform the action, it is `403`. The same transition by different roles (guest or owner cancelling) is one method.

## Methods

- `GET` reads and never changes state. `POST` on a collection creates. `PATCH` updates fields. `PUT` replaces a singleton or adds/updates a join resource; collection items are never `PUT`. `DELETE` removes (on a singleton, resets it).
- Custom methods are `POST` with a camelCase verb as the last segment:
  - on an item: `POST /orders/:orderId/cancel`;
  - on a collection, for batches and for targets identified by a secret instead of an id: `POST /documents/batchDelete`, `POST /sessions/refresh`, `POST /passwordResets/confirm`;
  - nested under an owner when scoped to it: `POST /users/me/sessions/revokeAll` (all but the current session).
- Name transitions by who performs them: `cancel` by the side that created the resource (guest, inviter); `accept` / `decline` by the recipient (invitee); `confirm` / `reject` by the side that approves it (restaurant, admin). Other verbs only for transitions these do not describe (`markReady`, `pickUp`, `deliver`).
- `PATCH` vs custom method. Use a custom method only when the change:
  - writes a lifecycle or status field (`cancel`, `confirm`, `scheduleDeletion`);
  - has a state precondition that can fail with `409` (`resume` after the period ended);
  - charges money or creates, deletes or changes other resources (`changePlan`, `makeDefault`, `changePassword` revoking sessions).
  Notifications, derived counters, search indexes and permissions computed from the data do not count. Everything else is `PATCH` (rename, visibility, `pinned` flag, profile fields).
- `DELETE` removes the resource from the API; afterwards item `GET` is `404`. Audit logs, snapshots kept by other resources (an invoice line copying a discount) and placeholders that only keep a thread intact (a deleted message shown as deleted) do not count as the record staying. If clients still read the record with a new status (cancelled order, account pending deletion), use a custom method.
- Model processes with their own lifecycle as resources: sign in is `POST /sessions`; a password reset is `POST /passwordResets` then `POST /passwordResets/confirm`; email verification is created by sign up or `POST /emailVerifications` (resend, authenticated), confirmed by `POST /emailVerifications/confirm`; an email change is `POST /users/me/emailChanges` then `POST /emailChanges/confirm`; an invitation that must be accepted is `POST /channels/:channelId/invitations` then `POST /invitations/:invitationId/accept`. When direct adding is allowed, it is the join `PUT`; the invitation is the path for users who must consent.
- Idempotency:
  - `GET`, `PUT` and `DELETE` are idempotent in effect; repeating `DELETE` on a removed resource is `404`;
  - transitions are idempotent: repeating `cancel` on a cancelled order is `200` with the current state; from an incompatible state it is `409`; a transition that can only move forward (read position) ignores backward moves and returns `200` with the current state;
  - every `POST` that spends money or reserves limited capacity (orders, payments, refund requests, `changePlan`, `pay`, reservations, `reschedule`) accepts an `Idempotency-Key` header: a retry within 24 h returns the first response (status and body); the same key with a different body is `422`; a retry while the first is still running is `409`.

## Query params

- Query params filter, sort and page lists, or supply inputs to computed views. They never change the shape of returned objects (no `fields`, `expand`, `include`).
- Equality filters by field name: `?status=paid`; several values comma-separated: `?status=paid,shipped`.
- Ranges, inclusive: `<name>From` / `<name>To`, where `<name>` drops the `At` suffix (`createdAt` → `createdFrom`, `createdTo`); numbers use `<field>Min` / `<field>Max` (`priceMin`).
- Full-text search: `?query=…` on the list, sorted by relevance unless `sortBy` is given. Use `POST …/search` only when the query needs a structured body.
- Sorting: `?sortBy=createdAt&sortDirection=desc`.
- Paging. The style is part of the contract (switching is breaking), so pick it by the list's nature:
  - the style is fixed per endpoint by what the list is; an optional `?query` on a browse list (`GET /events?query=…`) does not change it;
  - cursors for feeds, chat messages, activity and history logs (sessions, orders, invoices, usage records), and endpoints whose purpose is search across owners (`GET /messages?query=…`): `?cursor=…&perPage=20`;
    - `nextCursor` continues in the list's sort direction, `prevCursor` goes back; both are `null` at the ends;
    - cursors are opaque and encode filters and sort; with `cursor` only `perPage` is allowed, anything else is `422`;
    - `?anchor=<id>` is used only on the first request instead of `cursor`, accepts the normal filters and sort, and returns a page containing the anchor item roughly in the middle, with both cursors set;
  - pages for every other list: `?page=1&perPage=20`;
  - `perPage` is 1–100, default 20; outside that range is `422`.

## Values

- A resource's own id is `id`; references are `<resource>Id` (`folderId`). Ids are strings.
- Points in time are instants, ISO 8601 in UTC: `"startsAt": "2026-10-24T17:00:00Z"`. Calendar concepts without an instant (opening hours, a day's waiting list, availability queries) use local `"date": "2026-10-24"` and `"time": "19:00"` in the resource's `timeZone` (IANA name).
- Money is an integer in minor units with one `currency` per object: `{ "subtotal": 3998, "total": 4498, "currency": "USD" }`. Several currencies are an array of such objects: `prices: [{ "amount": 900, "currency": "EUR" }]`.
- Server-generated human text in data (invoice line descriptions, system messages) is an i18n key with `params`, like errors: `{ "description": "billing.invoiceLine.unusedTime", "params": { "planId": "plan_basic" } }`.
- In responses, optional fields without a value are `null`, never omitted. In `PATCH` bodies an omitted field is unchanged and `null` clears it ([RFC 7396](https://www.rfc-editor.org/rfc/rfc7396)).
- A resource embeds small owned children it is always read with (order → `orderItems`, message → `attachments`) and computed summaries (`replyCount`, `reactionSummary`); everything else is read through its own list endpoint.
- Clients must ignore unknown fields and handle unknown enum values.
- A file is an object field named after its role, never flat prefixed fields: `"deliveryProof": { "downloadUrl": "…", "downloadUrlExpiresAt": "…", "contentType": "image/jpeg", "size": 48211 }`; `null` when there is none. A write referencing an upload names the field `<role>UploadId` (`deliveryProofUploadId`) or `<role>UploadIds` for several.
- Responses may contain secrets meant for the caller (tokens, payment client secrets); they are never logged.

## Responses

Every JSON response uses one envelope:

```json
{ "success": true, "errors": [], "messages": [], "result": {} }
```

- `success` is `true` for every 2xx (including batches where all items failed and accepted jobs) and `false` for every 4xx and 5xx.
- `errors` and `messages` are always arrays. `messages` holds non-fatal notices (e.g. deprecation) in the same `{ code, message, params }` shape as errors, without `field`.
- `result` is:
  - the affected resource after create, update, item custom method and item `GET`;
  - the list object for list `GET`, the batch report for batch methods, the job for job starts;
  - `null` after `DELETE`, on errors, and for collection custom methods unless stated otherwise (`POST /sessions/refresh` returns the session; `revokeAll` and process confirmations return `null`).
- A list is never a bare array. Every list endpoint returns the same object, with every key always present:

  ```json
  {
    "success": true, "errors": [], "messages": [],
    "result": {
      "items": [],
      "pagination": { "count": 0, "perPage": 20, "page": 1, "totalCount": 0, "nextCursor": null, "prevCursor": null }
    }
  }
  ```

  - `count` is the number of `items` in this response;
  - page lists fill `page` and `totalCount`; `nextCursor` and `prevCursor` are `null`;
  - cursor lists fill `nextCursor` and `prevCursor`; `page` and `totalCount` are `null`;
  - lists that are not paged today (small fixed sets) return the full set with `page: 1` and `perPage` and `totalCount` equal to `count`, so paging can be added without a breaking change;
  - arrays embedded in a resource (`orderItems` in an order) are fields, not lists, and stay plain arrays.
- Errors are `{ code, message, params, field }`; the same shape is used everywhere an error appears (jobs, batches):
  - `message` is an i18n key, never human text: `<app>.<area>.<reason>` in camelCase, e.g. `identity.signIn.invalidCredentials`. The backend has no translations; clients localize the key;
  - `params` holds the values the translation interpolates (`{ "max": 100 }`), `{}` when there are none; never pre-formatted text;
  - `code` is the stable number of the same error, for logs and programmatic checks; keys and codes are one-to-one;
  - `field` is the input that failed (`orderItems.0.quantity` for nested inputs) or `null`.

  ```json
  { "code": 1001, "message": "identity.signIn.invalidCredentials", "params": {}, "field": null }
  { "code": 102, "message": "common.validation.tooLong", "params": { "max": 100 }, "field": "displayName" }
  ```

- Generic validation errors (`required`, `tooLong`, `invalidFormat`) use shared `common.validation.*` keys with the constraint in `params`.
- Error codes and keys are defined together in one enum per app; numeric ranges: `common` 100–999 (shared, in `src/common`), identity 1000–1999. A new app takes the next free thousand and adds itself to this list.
- Status codes:
  - `200` read, update, custom method, `DELETE`, every batch method (including `batchCreate`, no `Location`), `PUT` on an existing join or singleton;
  - `201` create, including `PUT` that creates a join and custom methods whose result is a new resource (`promote` returns the reservation). A transition that also creates side resources (`accept` creating a membership) is `200` with the transitioned resource; `202` async job accepted. Every `201` and job `202` sets `Location` to the item's flat path, or to the join path for joins;
  - `400` the body cannot be parsed (malformed JSON or multipart);
  - `401` missing, invalid or expired credentials: access and refresh tokens, a wrong password at sign in, a bad webhook signature. Bearer endpoints also send `WWW-Authenticate: Bearer` ([RFC 6750](https://www.rfc-editor.org/rfc/rfc6750)). A wrong current password on an authenticated call (`changePassword`) is `422` on `currentPassword`, never `401`, so clients do not sign the user out;
  - `403` the caller can read the target but may not perform the action;
  - `404` the path target does not exist or is not visible to the caller;
  - `409` the request conflicts with the state of the path target (slot taken, invalid transition, duplicate unique value);
  - `410` only for resources whose expiry is part of their contract (an expired export); deleted resources are `404`;
  - `413` payload too large; `415` the route does not accept the `Content-Type`;
  - `422` the request fails validation, including references the server cannot resolve: unknown ids in the body, unknown, expired or used process tokens (reset, verification), too many batch items;
  - `429` rate limited.
- Do not reveal whether an account exists: sign in returns the same `401` for an unknown email and a wrong password; `POST /passwordResets` always returns `202` with `result: null` and no `Location` (the only `202` that is not a job). Sign up or an email change to a taken email is `409`; this leak is accepted and rate-limited.
- Binary content is the only exception to the envelope. Expose files as a short-lived signed `downloadUrl` with `downloadUrlExpiresAt` on the owning resource (invoice, attachment, avatar, finished export).

## Auth

- Clients send `Authorization: Bearer <accessToken>`; other services call the same endpoints with a service token.
- Sign in (`POST /sessions`, `201`) returns the session with `accessToken`, `refreshToken` and their expiry instants; sign up (`POST /users`, `201`) returns only the user.
- Refresh: `POST /sessions/refresh` with `{ refreshToken }`. Sign out: `DELETE /sessions/current`. List sessions: `GET /users/me/sessions`. Revoke one: `DELETE /sessions/:sessionId`.
- Secrets (passwords, tokens, reset codes) go in the request body, never in the path or query.

## Async work, uploads, bulk, webhooks

- A long operation the client waits for is a job resource: `POST` returns `202` with `{ id, status, progress, result, error }`; the client polls `GET` on the item. Job output is nested as `result.result` on purpose.
  - `status` is `pending | running | succeeded | failed | cancelled`; `progress` is 0–100;
  - output goes in the job's `result`; failure goes in its `error` while the poll itself is `200`;
  - cancel is a custom method (`POST /exports/:exportId/cancel`).
- When a resource waits on an external party or background processing, it is not a job: return it with a status that says so (`processing`, `requiresAction` with a `nextAction` object), `201` or `200` as usual; the client polls the resource or is told by push.
- Uploads:
  - a resource that is a file (photo, document) is created by `POST` to its collection with `multipart/form-data` (`file` + fields), returning it (`status: processing` while it is being handled);
  - files referenced by another resource (message attachments, delivery proof) are uploaded first with `POST /uploads` → `{ id }` and referenced by `<role>UploadId(s)` (`attachmentUploadIds`);
  - a file on an existing resource is a singleton: `PUT /users/me/avatar`.
- Bulk, max 100 items unless the endpoint documents a higher limit for machine ingestion (more is `422`):
  - on existing items: `POST /<resources>/batch<Verb>` with `{ ids }`, result `{ succeededIds, failed: [{ id, error }] }`; unknown or invisible ids go to `failed` with the not-found code;
  - create: `POST /<resources>/batchCreate` (nested under the owner when scoped to it) with `{ items }`, result `{ created: [...], failed: [{ index, error }] }`; items carry a client `idempotencyKey` so retries do not duplicate them.
- Webhooks from providers: `POST /webhooks/<provider>` (no `/v1` prefix), authenticated by the provider's signature header (bad signature is `401`). Respond `200` with the envelope right after verifying and storing the event, deduplicate by the provider's event id, process it in the background.
- Real-time delivery (WebSocket, SSE) is out of scope of this skill.

## Versioning

- Major version is the first path segment: `/v1/users` ([AIP-185](https://google.aip.dev/185)). Set up in `src/app.setup.ts` (Nest URI versioning, default `1`). Infra endpoints (`/healthz`, `/webhooks/*`) are `VERSION_NEUTRAL`.
- Additive changes stay in the current version: new optional request fields, new response fields, new enum values in responses, new endpoints, new optional query params.
- Breaking changes need a new major ([AIP-180](https://google.aip.dev/180)): removing or renaming fields or enum values, making a field required, changing types, formats, paging style or semantics. Batch breaking changes into one new major.
- A major covers the whole API. When adding `v2`, unchanged controllers serve both: `version: ['1', '2']`; changed ones get one controller per version (`users-v1.controller.ts`, `users-v2.controller.ts`), or `@Version` per method when only some routes change. Services, tables and business logic stay version-agnostic; only DTOs and mappers know versions.
- The old major is frozen: it gets no new features and keeps working on the new storage via mappers; a write that cannot be mapped losslessly is `422` with a code pointing to the new major. Every response from a deprecated major carries a deprecation notice in `messages` and these headers:
  - `Deprecation: @<unix seconds of the new major's release>` ([RFC 9745](https://www.rfc-editor.org/rfc/rfc9745));
  - `Sunset: <HTTP-date>` ([RFC 8594](https://www.rfc-editor.org/rfc/rfc8594)), at least 6 months after the new major ships;
  - `Link: </v2/users>; rel="successor-version"`.

## Example

```text
GET    /v1/users/me                                   current user
GET    /v1/users/me/cart                              singleton
POST   /v1/users/me/cart/cartItems                    children of a singleton
PATCH  /v1/cartItems/:cartItemId                      item path is flat
GET    /v1/users/:userId/accounts                     list accounts of a user
POST   /v1/users/:userId/accounts                     link an account
GET    /v1/accounts/:accountId                        account details
PATCH  /v1/accounts/:accountId                        update an account
DELETE /v1/accounts/:accountId                        unlink an account
POST   /v1/accounts/:accountId/makePrimary            custom method on an item
POST   /v1/users/me/sessions/revokeAll                custom method on an owned collection
PUT    /v1/channels/:channelId/members/:userId        join resource by natural key

GET    /v1/users/:userId/accounts/:accountId          ✗ item paths are flat
GET    /v1/users/:userId/accounts/:accountId/sessions ✗ one parent collection at most
POST   /v1/users/:userId/update                       ✗ verb for CRUD, use PATCH
GET    /v1/admin/orders                               ✗ role in the path, use 403
```

## Workflow

1. List the resources (nouns), their owners, singletons, join resources, and processes with a lifecycle.
2. Write the endpoint table (method, path, purpose), then request and response bodies, before writing controllers.
