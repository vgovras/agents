# Example: action over several modules

Illustrative only. Copy the structure, never the names, logic or values.

```
src/
├── actions/
│   ├── <entity>-<action>.command    # <Entity><Action>Command + handler
│   └── <entity>-<other>.query
├── actions.module                   # registers every handler
├── modules/
│   ├── <feature>/                   # entry point only: controller → bus
│   │   ├── dto/
│   │   ├── <feature>.controller
│   │   └── <feature>.module
│   ├── <module-a>/
│   │   ├── <module-a>.service       # data access + logic shared by 2+ features
│   │   └── <module-a>.module
│   └── <module-b>/
│       ├── <module-b>.service
│       └── <module-b>.module
└── libs/<tech>/
    └── <tech>.service
```

```
<entity>-<action>.command
  execute(command):
    a = moduleA.lock(command.id)                 # shared with other callers
    if not a: fail <Error>
    if not this.canApply(a): fail <OtherError>   # feature rule: private method here
    b = this.insertB(a.id)                       # data access only this action needs: private method on the table
    return { a, b }

<feature>.controller
  POST /<entities>/:id/<action> (body)
    result = bus.execute(new <Entity><Action>Command({ id, ...body }))
    return <Entity>Dto.fromResult(result)
```
