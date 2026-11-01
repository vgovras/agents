---
name: backend-module-structure
description: Backend architecture rules for any language — where files go and how logic splits between actions, modules, common and libs. Use any time backend code is written or changed, whatever the feature or stack.
---

# Backend module structure

Code is grouped by feature, not by technical layer. No layer exists only to pass a call through.

## Top-level layout

```
src/
├── actions/   # flat: one file per feature operation (command or query)
├── modules/   # domain code: one folder per domain (user, session, order…)
├── common/    # app-wide code with no domain: errors, filters, base DTOs, shared types
└── libs/      # technical code with no business rules (db, jwt, cache, http client)
```

## Files and imports

- `<name>.<role>.<ext>` — role is always in the file name. Roles: `controller`, `service`, `schema` (table), `model`, `dto`, `types`, `constants`, `enum`, `config`, `module`, `command`, `query`, `spec`.
- No `index` / barrel files. Import the file itself.
- Same folder: relative `./x`. Anything else: the project root alias (`#src/...`). Never `../`.
- 2+ files of one role in a module → a folder per role: `dto/`, `services/`, `schemas/`, `enums/`, `models/`.
- No `utils` files. Technical helpers live in `libs/`; everything else goes into an action or a service.
- No exported free functions outside `libs/` (decorators excepted): make them static or instance methods of the class that owns them.

## Actions

- `src/actions/` is flat: `<entity>-<action>.command` or `<entity>-<action>.query`. The class name matches the file (`order-cancel.command` → `OrderCancelCommand`).
- One action = one feature operation. Its rules and orchestration live in the action — `execute()` plus private methods.
- Move code into an action when it uses 2+ modules, or when a service method needs its own private helper methods.
- A service method used by exactly one action becomes a private method of that action.
- Called only through the framework's command/query bus, from anywhere: controllers, consumers, jobs.
- Handlers are registered in one place for all actions (e.g. an `ActionsModule`), not in feature modules.

## Modules

- One folder per domain: `modules/<domain>/`.
- Services hold data access and logic shared by 2+ callers. A method or rule used by one action belongs to that action.
- No top-level functions in a service file; everything is a method of the service.
- Plain CRUD on one module: controller → that module's service. Anything with an action: controller → bus.
- No repository layer — the ORM is the repository, used inside services.
- A module may have only a controller (entry point that calls the bus) and no data of its own.

## Public files of a module

Another module, an action or `common/` imports only these files of a module:
`*.service`, `*.types`, `*.constants`, `*.module`, `*.model`, `*.enum`.
Actions may also import `*.schema` (tables) for their own data access.

Private: `dto/`, `*.controller`, `*.schema` (except for actions), everything else.

## Input validation

- All request validation, checks and type conversion happen at the controller edge (DTOs, pipes); services and actions receive valid, typed values and don't re-check them.
- Non-HTTP input (file rows, messages, job payloads) is validated where it is parsed.

## Libs and common

- `libs/`: technical, reusable, no business rules. Imports nothing from the app.
- `common/`: app-wide code without a domain. Never imports `modules/` or `actions/`.

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
│   └── <type>/<vendor>/         # e.g. sms/<vendor>/, email/<vendor>/
│       ├── <vendor>.types
│       ├── <vendor>.config
│       ├── <vendor>.service     # implements channel.interface
│       └── <vendor>.module
├── <domain>.service             # picks the channel, calls it
└── <domain>.module
```

New vendor = new folder. Nothing else changes. Vendor SDKs and credentials never leave their folder; other modules import only `<domain>.service`.

## Dependency rules

| From → To | Allowed |
|---|---|
| actions → modules (public files + schemas), common, libs | yes |
| modules → libs, common | yes |
| modules → modules | public files only |
| modules → actions | controllers only (and their dto files, type-only): command/query classes and result types |
| common → libs | yes |
| common → modules, actions | no |
| libs → anything in the app | no |
| action → action | no — extract to a module service or emit an event |

## Anti-patterns

- `index` barrels; `../` imports; `utils` files or exported free functions outside `libs/`.
- A service method only one action calls.
- Re-validating input in a service or action that the controller edge already validated.
- One feature's rules in a module service — they belong to its action.
- Business logic in controllers, `common/` or `libs/`.
- Repository layer over the ORM.
- Folders by layer (`controllers/`, `services/`) at the top level.
- Abstract names a junior wouldn't understand (`ports`, `adapters`, `infrastructure`).

## New feature checklist

```
- [ ] Plain CRUD on one domain? → module controller + service, stop.
- [ ] Uses 2+ modules or needs private helpers? → src/actions/<entity>-<action>.command|query, registered with the other handlers
- [ ] New domain data? → new folder in modules/
- [ ] Logic or data access shared by 2+ callers? → <domain>.service; used by one action → private method of the action
- [ ] Input validated and converted at the controller edge (or where non-HTTP input is parsed)
- [ ] Third-party vendor? → channels/<type>/<vendor>/
- [ ] Technical helper with no business meaning? → libs/
- [ ] 2+ files of one role → role folder
- [ ] Cross-module imports only of public files; no index, no ../
```

## Examples

Illustrative only. Copy the structure, never the names, logic or values.

- Plain CRUD module: [examples/crud.md](examples/crud.md)
- Action over several modules: [examples/action.md](examples/action.md)
- Module with vendor channels: [examples/channels.md](examples/channels.md)
