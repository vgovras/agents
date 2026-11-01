# Example: plain CRUD module

Illustrative only. Copy the structure, never the names, logic or values.

```
modules/<entity>/
├── <entity>.entity
├── <entity>.dto
├── <entity>.controller
├── <entity>.module
└── index
```

```
<entity>.controller
  POST   /<entities>      (body) → return db.<entity>.insert(body)
  GET    /<entities>/:id         → return db.<entity>.find(id) or fail NotFound
  PATCH  /<entities>/:id  (body) → return db.<entity>.update(id, body)
  DELETE /<entities>/:id         → db.<entity>.delete(id)
```

No service, no repository. Add `<entity>.service` only when a rule appears.
