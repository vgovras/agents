# Example: plain CRUD module

Illustrative only. Copy the structure, never the names, logic or values.

```
modules/<entity>/
├── dto/
│   ├── create-<entity>.dto     # Create<Entity>ReqDto; response is the shared <Entity>Dto
│   ├── list-<entities>.dto     # List<Entities>ReqDto, List<Entities>ResDto
│   └── <entity>.dto            # shared response shape + static factory
├── <entity>.schema
├── <entity>.model
├── <entity>.service
├── <entity>.controller
└── <entity>.module
```

```
<entity>.service
  create(input) → db.insert(<entity>).values(input).returning()
  list(filter)  → db.query.<entity>.findMany(filter)
  delete(id)    → db.delete(<entity>).where(id) or fail NotFound

<entity>.controller
  POST   /<entities>     (body) → <Entity>Dto.from<Entity>(service.create(body))
  GET    /<entities>            → List<Entities>ResDto.fromPage(service.list(query))
  DELETE /<entities>/:id        → service.delete(id)
```

No action: one module, no private helpers.
