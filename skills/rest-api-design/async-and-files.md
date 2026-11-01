# Async work, uploads, bulk, webhooks

## Jobs

- A long operation the client waits for is a job resource: `POST` returns `202` with `{ id, status, progress, result, error }`; the client polls `GET` on the item. Job output is nested as `result.result` on purpose.
  - `status` is `pending | running | succeeded | failed | cancelled`; `progress` is 0–100;
  - output goes in the job's `result`; failure goes in its `error` while the poll itself is `200`;
  - cancel is a custom method (`POST /exports/:exportId/cancel`).
- When a resource waits on an external party or background processing, it is not a job: return it with a status that says so (`processing`, `requiresAction` with a `nextAction` object), `201` or `200` as usual; the client polls the resource or is told by push.

## Uploads

- A resource that is a file (photo, document) is created by `POST` to its collection with `multipart/form-data` (`file` + fields), returning it (`status: processing` while it is being handled).
- Files referenced by another resource (message attachments, delivery proof) are uploaded first with `POST /uploads` → `{ id }`; the write references them as `<role>UploadId` (`deliveryProofUploadId`) or `<role>UploadIds` for several.
- A file on an existing resource is a singleton: `PUT /users/me/avatar`.

## Bulk

Max 100 items unless the endpoint documents a higher limit for machine ingestion (more is `422`):

- on existing items: `POST /<resources>/batch<Verb>` with `{ ids }`, result `{ succeededIds, failed: [{ id, error }] }`; unknown or invisible ids go to `failed` with the not-found code;
- create: `POST /<resources>/batchCreate` (nested under the owner when scoped to it) with `{ items }`, result `{ created: [...], failed: [{ index, error }] }`; items carry a client `idempotencyKey` so retries do not duplicate them.

## Webhooks from providers

- `POST /webhooks/<provider>`, no version prefix, authenticated by the provider's signature header (bad signature is `401`).
- Respond `200` with the envelope right after verifying and storing the event, deduplicate by the provider's event id, process it in the background.

Real-time delivery (WebSocket, SSE) is out of scope of this skill.
