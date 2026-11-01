# Example: action over several modules

Illustrative only. Copy the structure, never the names, logic or values.

```
actions/<domain>/
└── <verb-noun>.command

modules/
├── <domain>/
│   ├── <domain>.controller      # entry point, calls the bus only
│   ├── <verb-noun>.dto
│   └── <domain>.module
├── <module-a>/                  # has a service because it has rules
│   ├── <module-a>.service
│   └── index
└── <module-b>/
    ├── <module-b>.service
    └── index

libs/<tech>/
├── <tech>.service
└── index
```

```
<verb-noun>.command
  execute(input):
    a = moduleA.find(input)
    if not a: fail <Error>
    b = moduleB.create(a.id)
    return tech.do(a, b)

<domain>.controller
  POST /<domain>/<verb> (body) → return bus.execute(<VerbNoun>Command(body))
```
