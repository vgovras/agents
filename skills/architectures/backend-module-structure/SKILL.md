---
name: backend-module-structure
description: Backend architecture rules for any language — where files go and how logic splits between actions, modules and libs. Use any time backend code is written or changed, whatever the feature or stack.
---

# Backend module structure

Code is grouped by feature, not by technical layer. No layer exists only to pass a call through.

## Top-level layout

```
src/
├── actions/   # business use cases: one class, one execute()
├── modules/   # domain code: one folder per domain (user, session, order…)
└── libs/      # technical code with no business rules (db, jwt, cache, http client)
```

## File naming

`<name>.<role>.<ext>` — role is always in the file name.

Roles: `controller`, `service`, `entity`, `dto`, `types`, `config`, `module`, `command`, `query`, `template`, `spec`.
Each folder that others import from has an `index` file — its public API.

## Actions

- One action = one business operation: `actions/<domain>/<verb-noun>.command` or `.query`.
- Contains only the action class with a single `execute()`. Nothing else lives in `actions/`.
- Orchestrates modules and libs. Owns the transaction boundary.
- Called only through the framework's command/query bus, from anywhere: controllers, consumers, jobs.
- Create an action when an operation touches more than one module, or has business steps beyond plain CRUD.

## Modules

- One folder per domain: `modules/<domain>/`.
- May have its own controller for plain CRUD on its own data.
- Plain CRUD: controller → ORM directly. No service, no repository.
- Add a `service` only when there are rules: validation against data, hashing, invariants, normalization, domain events.
- No repository layer — the ORM is the repository.
- Entry points for actions (e.g. `auth.controller`) live in a module and only call the bus.

## Libs

- Technical, reusable, no business rules. Know nothing about modules or actions.

## Top-level or nested?

Ask in order, stop at first yes:

1. Will anything outside the parent use it directly? → top-level `modules/<name>/`.
2. Is it one interchangeable implementation of the parent's capability (a vendor, a provider, a strategy)? → nested in the parent: `channels/<type>/<vendor>/`.
3. Is it a private part of the parent with no meaning on its own? → nested folder or file inside the parent.
4. Otherwise → top-level.

Signal for a capability module with nested vendors: the task names an action that can be done by more than one external service ("send", "pay", "store a file", "verify identity"). Build the capability (`notification`, `payment`, `storage`) as a module, put the vendor inside it — even if there is only one vendor today.

## External vendors

Group by channel type, then vendor. Each vendor is a full sub-module.

```
modules/<domain>/
├── channels/
│   ├── channel.interface        # what every vendor must implement
│   ├── <type>/<vendor>/         # e.g. sms/<vendor>/, email/<vendor>/
│   │   ├── <vendor>.types
│   │   ├── <vendor>.config
│   │   ├── <vendor>.service     # implements channel.interface
│   │   ├── <vendor>.module
│   │   └── index
├── <domain>.service             # picks the channel, calls it
└── index                        # exports only <domain>.service
```

New vendor = new folder. Nothing else changes. Vendor SDKs and credentials never leave their folder.

## Dependency rules

| From → To | Allowed |
|---|---|
| actions → modules, libs | yes |
| modules → libs | yes |
| modules → modules | only through `index` |
| modules → actions | only via bus |
| libs → anything | no |
| action → action | no — extract to a module or emit an event |

Never import another folder's internal files — only its `index`.

## Anti-patterns

- Service or repository that only forwards the call.
- Business logic in controllers or libs.
- Domain rules in actions — they belong to the module's service; actions only orchestrate.
- Folders by layer (`controllers/`, `services/`) at the top level.
- Abstract names a junior wouldn't understand (`ports`, `adapters`, `infrastructure`).

## New feature checklist

```
- [ ] Is it plain CRUD on one domain? → module controller + ORM, stop.
- [ ] Touches several modules or has business steps? → add action in actions/<domain>/
- [ ] New domain data? → new folder in modules/
- [ ] Domain rules? → <domain>.service
- [ ] Third-party vendor? → channels/<type>/<vendor>/
- [ ] Technical helper with no business meaning? → libs/
- [ ] All cross-folder imports go through index
```

## Examples

Illustrative only. Copy the structure, never the names, logic or values.

- Plain CRUD module: [examples/crud.md](examples/crud.md)
- Action over several modules: [examples/action.md](examples/action.md)
- Module with vendor channels: [examples/channels.md](examples/channels.md)
