# Versioning

- Major version is the first path segment: `/v1/users` (AIP-185). Infra endpoints (`/healthz`, `/webhooks/*`) have no version.
- Changing the paging style of a list is breaking, like removing, renaming or retyping fields. Batch breaking changes into one new major.
- A major covers the whole API. Unchanged endpoints serve both majors; changed ones get a per-version controller or route. Services, tables and business logic stay version-agnostic; only DTOs and mappers know versions.
- The old major is frozen: it gets no new features and keeps working on the new storage via mappers; a write that cannot be mapped losslessly is `422` with a code pointing to the new major.
- Every response from a deprecated major carries a deprecation notice in `messages` and these headers:
  - `Deprecation: @<unix seconds of the new major's release>` (RFC 9745);
  - `Sunset: <HTTP-date>` (RFC 8594), at least 6 months after the new major ships;
  - `Link: </v2/users>; rel="successor-version"`.
