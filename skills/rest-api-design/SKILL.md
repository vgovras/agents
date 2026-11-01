---
name: rest-api-design
description: REST API rules — paths, methods, params, values, response envelope, errors, status codes. Use any time an HTTP endpoint or controller is designed, added, changed or reviewed, including plans that list endpoints.
---

# REST API Design

Resource-oriented design with custom methods for non-CRUD operations (Google AIP-121, AIP-136).
Everything is `camelCase`: paths, path params, query params, JSON fields, multipart field names.

Read when the task has them:
- jobs, uploads, bulk, webhooks → [async-and-files.md](async-and-files.md)
- sign in, sessions, tokens, password reset → [auth.md](auth.md)
- a new major version or a breaking change → [versioning.md](versioning.md)

## Resources and paths

- Resources are plural nouns. Item paths are flat, so names are global:
  - plain name when unambiguous across the API (`comments`);
  - several owners have children of the same kind → prefix all of them with the owner (`orderItems`, `cartItems`);
  - generic words (`items`, `sections`, `types`, `transfers`, `settings`, `entries`) are always prefixed (`seatingSections`, `ticketTransfers`) — renaming a published resource is breaking;
  - join resources have no flat path and keep plain names (`members`).
- List and create are nested under the owner; operations on one item use its flat path:
  - `GET /folders/:folderId/documents`, `POST /folders/:folderId/documents`;
  - `GET /documents/:documentId`, `PATCH /documents/:documentId`, `DELETE /documents/:documentId`.
  Top-level resources have no owner: `GET /workspaces`. A path has at most one parent collection.
- The owner is the resource the item belongs to in its lifecycle: the side a client operation targets (a reservation belongs to its restaurant), or the resource that produced it (an invoice belongs to its subscription). Resources created before their owner is known are top-level (`POST /sessions` at sign in).
- Extra lists, all limited to what the caller may see:
  - from an ancestor: `GET /workspaces/:workspaceId/documents`;
  - from the other side of a relation: `GET /users/me/reservations`;
  - across all owners, at the top level with filters: `GET /messages?query=…&channelId=…`;
  - of related items of the same type: `GET /messages/:messageId/replies` returns messages; `POST` to it creates one, with `Location` at `/messages/:messageId`.
- Join resources (membership, reaction, pin) link a parent to something with a public, URL-safe key and have no id of their own. They live only at `/<parents>/:parentId/<joins>/:key`:
  - `GET /channels/:channelId/members` lists, `PUT /channels/:channelId/members/:userId` adds or updates (body: the join's fields, e.g. `{ role }`), `DELETE` removes;
  - keys are identifiers, never raw Unicode or secrets: `PUT /messages/:messageId/reactions/thumbsUp`. Applying a coupon code is a create with the code in the body: `POST /subscriptions/:subscriptionId/discounts`.
- A singleton is a singular noun that exists exactly once per owner and is part of the owner's path (it does not count as a parent):
  - `GET` always returns `200` with the full object (unset fields `null`, lists `[]`); `PUT` replaces it, `PATCH` updates it, `DELETE` resets it to empty; no `POST`;
  - its children nest under it: `POST /users/me/cart/cartItems`, then `PATCH /cartItems/:cartItemId`;
  - it may be per caller when the owner is shared: `GET /channels/:channelId/readState`; owner list items embed it (`channel.readState`) so clients do not fetch it per owner;
  - a file attached to an existing resource is a singleton uploaded with multipart `PUT`: `PUT /users/me/avatar`;
  - name it as a noun phrase when the concept is plural: `openingSchedule`.
  Use a collection instead when instances have history or are created by a paid action (`GET /users/me/subscriptions?status=active`).
- Computed read-only views use singleton paths, support only `GET`, and take their inputs as query params: `GET /restaurants/:restaurantId/availability?date=…&partySize=…`.
  - A preview of a write is such a view: `GET /subscriptions/:subscriptionId/prorationPreview?planId=…`.
  - Inputs that do not fit in query params (a cart of items) → `POST` to the write's path plus `/preview` with the write's body: `POST /restaurants/:restaurantId/orders/preview`, `200`, creates nothing.
- A grouping without its own id (a restaurant's waiting list for a day) is not a resource: list its members with a required filter (`GET /restaurants/:restaurantId/waitlistEntries?date=2026-10-24`, missing `date` is `422`).
- Pseudo-ids for the caller: `me` for `:userId`, `current` for `:sessionId`.
- Roles share the same paths (no `/admin/…`); access is decided by status code (see Status codes). The same transition by different roles (guest or owner cancelling) is one method.

## Methods

- `POST` on a collection creates. `PATCH` updates fields. `PUT` replaces a singleton or adds/updates a join resource; collection items are never `PUT`. `DELETE` removes (on a singleton, resets it).
- Custom methods are `POST` with a camelCase verb as the last segment:
  - on an item: `POST /orders/:orderId/cancel`;
  - on a collection, for batches and for targets identified by a secret instead of an id: `POST /documents/batchDelete`, `POST /sessions/refresh`, `POST /passwordResets/confirm`;
  - nested under an owner when scoped to it: `POST /users/me/sessions/revokeAll` (all but the current session).
- Name transitions by who performs them: `cancel` by the side that created the resource (guest, inviter); `accept` / `decline` by the recipient (invitee); `confirm` / `reject` by the side that approves it (restaurant, admin). Other verbs only for transitions these do not describe (`markReady`, `pickUp`, `deliver`).
- Custom method instead of `PATCH` only when the change:
  - writes a lifecycle or status field (`cancel`, `confirm`, `scheduleDeletion`);
  - has a state precondition that can fail with `409` (`resume` after the period ended);
  - charges money or creates, deletes or changes other resources (`changePlan`, `makeDefault`, `changePassword` revoking sessions).
  Notifications, derived counters, search indexes and permissions computed from the data do not count. Everything else is `PATCH` (rename, visibility, `pinned` flag, profile fields).
- `DELETE` removes the resource from the API; afterwards item `GET` is `404`. Audit logs, snapshots kept by other resources (an invoice line copying a discount) and placeholders that only keep a thread intact (a deleted message shown as deleted) do not count as the record staying. If clients still read the record with a new status (cancelled order, account pending deletion), use a custom method.
- Processes with their own lifecycle are resources:

  | Process | Start | Finish |
  |---|---|---|
  | sign in | `POST /sessions` | — |
  | password reset | `POST /passwordResets` | `POST /passwordResets/confirm` |
  | email verification | sign up, or `POST /emailVerifications` (resend, authenticated) | `POST /emailVerifications/confirm` |
  | email change | `POST /users/me/emailChanges` | `POST /emailChanges/confirm` |
  | invitation | `POST /channels/:channelId/invitations` | `POST /invitations/:invitationId/accept` |

  When direct adding is allowed, it is the join `PUT`; the invitation is the path for users who must consent.
- Idempotency:
  - `PUT` and `DELETE` are idempotent in effect; repeating `DELETE` on a removed resource is `404`;
  - transitions are idempotent: repeating `cancel` on a cancelled order is `200` with the current state; from an incompatible state it is `409`; a transition that can only move forward (read position) ignores backward moves and returns `200` with the current state;
  - every `POST` that spends money or reserves limited capacity (orders, payments, refund requests, `changePlan`, `pay`, reservations, `reschedule`) accepts an `Idempotency-Key` header: a retry within 24 h returns the first response (status and body); the same key with a different body is `422`; a retry while the first is still running is `409`.

## Query params

- Query params filter, sort and page lists, or supply inputs to computed views. They never change the shape of returned objects (no `fields`, `expand`, `include`).
- Equality filters by field name: `?status=paid`; several values comma-separated: `?status=paid,shipped`.
- Ranges, inclusive: `<name>From` / `<name>To`, where `<name>` drops the `At` suffix (`createdAt` → `createdFrom`, `createdTo`); numbers use `<field>Min` / `<field>Max` (`priceMin`).
- Full-text search: `?query=…` on the list, sorted by relevance unless `sortBy` is given. `POST …/search` only when the query needs a structured body.
- Sorting: `?sortBy=createdAt&sortDirection=desc`.
- Paging style is part of the contract (switching is breaking) and fixed per endpoint by what the list is; an optional `?query` on a browse list does not change it:
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
- In responses, optional fields without a value are `null`, never omitted. In `PATCH` bodies an omitted field is unchanged and `null` clears it (RFC 7396).
- A resource embeds small owned children it is always read with (order → `orderItems`, message → `attachments`) and computed summaries (`replyCount`, `reactionSummary`); everything else is read through its own list endpoint.
- A file is an object field named after its role, never flat prefixed fields: `"deliveryProof": { "downloadUrl": "…", "downloadUrlExpiresAt": "…", "contentType": "image/jpeg", "size": 48211 }`; `null` when there is none. Uploading it: [async-and-files.md](async-and-files.md).

## Responses

Every JSON response uses one envelope:

```json
{ "success": true, "errors": [], "messages": [], "result": {} }
```

- `success` is `true` for every 2xx (including batches where all items failed and accepted jobs) and `false` for every 4xx and 5xx.
- `errors` and `messages` are always arrays. `messages` holds non-fatal notices (e.g. deprecation) in the error shape, without `field`.
- `result` is:
  - the affected resource after create, update, item custom method and item `GET`;
  - the list object for list `GET`, the batch report for batch methods, the job for job starts;
  - `null` after `DELETE`, on errors, and for collection custom methods unless stated otherwise (`POST /sessions/refresh` returns the session; `revokeAll` and process confirmations return `null`).
- Binary content is the only exception to the envelope; files are exposed as a short-lived signed `downloadUrl` on the owning resource.

### Lists

A list is never a bare array. Every list endpoint returns this object as `result`, with every key always present:

```json
{
  "items": [],
  "pagination": { "count": 0, "perPage": 20, "page": 1, "totalCount": 0, "nextCursor": null, "prevCursor": null }
}
```

- `count` is the number of `items` in this response;
- page lists fill `page` and `totalCount`; `nextCursor` and `prevCursor` are `null`;
- cursor lists fill `nextCursor` and `prevCursor`; `page` and `totalCount` are `null`;
- lists not paged today (small fixed sets) return the full set with `page: 1` and `perPage` and `totalCount` equal to `count`, so paging can be added without a breaking change;
- arrays embedded in a resource (`orderItems` in an order) are fields, not lists, and stay plain arrays.

### Errors

`{ code, params, field }`, the same shape everywhere an error appears (jobs, batches):

```json
{ "code": "identity.signIn.invalidCredentials", "params": {}, "field": null }
{ "code": "common.validation.tooLong", "params": { "max": 100 }, "field": "displayName" }
```

- `code` is a string i18n key, never a number or human text: `<app>.<area>.<reason>` in camelCase. It is stable, used for logs and programmatic checks; the backend has no translations, clients localize the key.
- `params` holds the values the translation interpolates, `{}` when there are none; never pre-formatted text.
- `field` is the input that failed (`orderItems.0.quantity` for nested inputs) or `null`.
- Generic validation errors (`required`, `tooLong`, `invalidFormat`) use shared `common.validation.*` codes with the constraint in `params`.
- Codes are defined in one enum per app; shared `common.*` codes live in `src/common`.

### Status codes

| Code | When |
|---|---|
| `200` | read, update, custom method, `DELETE`, every batch method (including `batchCreate`, no `Location`), `PUT` on an existing join or singleton; a transition that also creates side resources (`accept` creating a membership) returns the transitioned resource |
| `201` | create, including `PUT` that creates a join and custom methods whose result is a new resource (`promote` returns the reservation) |
| `202` | async job accepted |
| `400` | the body cannot be parsed (malformed JSON or multipart) |
| `401` | missing, invalid or expired credentials (see [auth.md](auth.md)) |
| `403` | the caller can read the target but their role may not perform the action |
| `404` | the path target does not exist, is not visible to the caller, or its id in the path is malformed |
| `409` | the request conflicts with the state of the path target (slot taken, invalid transition, duplicate unique value) |
| `410` | only for resources whose expiry is part of their contract (an expired export); deleted resources are `404` |
| `422` | validation failed, including references in the body the server cannot resolve: unknown ids, unknown/expired/used process tokens, too many batch items |

Every `201` and job `202` sets `Location` to the item's flat path, or to the join path for joins.

## Example

Illustrative only. Copy the structure, never the names.

```text
GET    /v1/users/me                                   current user
GET    /v1/users/me/cart                              singleton
POST   /v1/users/me/cart/cartItems                    children of a singleton
PATCH  /v1/cartItems/:cartItemId                      item path is flat
GET    /v1/users/:userId/accounts                     list accounts of a user
POST   /v1/users/:userId/accounts                     link an account
GET    /v1/accounts/:accountId                        account details
DELETE /v1/accounts/:accountId                        unlink an account
POST   /v1/accounts/:accountId/makePrimary            custom method on an item
POST   /v1/users/me/sessions/revokeAll                custom method on an owned collection
PUT    /v1/channels/:channelId/members/:userId        join resource by natural key

GET    /v1/users/:userId/accounts/:accountId          ✗ item paths are flat
GET    /v1/users/:userId/accounts/:accountId/sessions ✗ one parent collection at most
POST   /v1/users/:userId/update                       ✗ verb for CRUD, use PATCH
GET    /v1/admin/orders                               ✗ role in the path, use 403
```

## Checklist

```
- [ ] Resources, owners, singletons, joins and lifecycle processes listed before controllers
- [ ] Endpoint table (method, path, purpose), then request and response bodies
- [ ] Plural camelCase nouns; generic words prefixed; item paths flat; ≤ 1 parent collection
- [ ] Custom method only for status, precondition (409) or side effects; else PATCH
- [ ] Money/capacity POSTs accept Idempotency-Key
- [ ] Paging style chosen by list nature; list object with full pagination
- [ ] Envelope everywhere; optional fields null, never omitted
- [ ] Errors { code, params, field } with string i18n codes
- [ ] Status codes per table; malformed path id is 404; Location on 201/202
```
