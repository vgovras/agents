---
name: nestjs
description: NestJS rules — CQRS commands and queries, controllers, modules, DTOs, response mapping, transactions. Use any time NestJS code is written or changed — a controller, module, provider, DTO, command, query or handler.
---

# NestJS

Folder layout and which code goes where: skill `backend-module-structure`. This skill is how it looks in NestJS.

## Libraries

- CQRS: `@nestjs/cqrs`. DTO derivation: `@nestjs/mapped-types`. Validation: `class-validator` + `class-transformer`.
- Transactions: `nestjs-cls` + `@nestjs-cls/transactional` with the ORM's adapter.

## Commands and queries

- One file `src/actions/<entity>-<action>.command.ts` (or `.query.ts`) holds the command class and its handler: `<Entity><Action>Command` + `<Entity><Action>Handler`.
- `extends Command<Result>` / `Query<Result>` so the bus returns a typed result. Export the result type from the same file; infer it where possible (`ReturnType<Handler['toState']>`).
- Fields on the class, no input interfaces:
  ```ts
  export class <Entity><Action>Command extends Command<<Result>> {
    readonly id: string;

    constructor(data?: CommandProps<<Entity><Action>Command>) {
      super();

      if (data) {
        Object.assign(this, data);
      }
    }
  }
  ```
  `CommandProps<T> = Omit<T, keyof Command<unknown>>` lives in `common/command-props.types.ts`; the same type serves queries.
- Feature rules are private methods of the handler.
- Every handler is registered in `src/actions.module.ts`, which imports the feature modules whose services the handlers use. `AppModule` imports `CqrsModule.forRoot()` and `ActionsModule`.
- Feature modules never import `actions/`, except controllers (and their dto files, type-only) importing command/query classes and result types.

## Controllers

- Dispatch actions with `CommandBus` / `QueryBus`; plain CRUD calls the module's service.
- All request validation, checks and type conversion happen here: DTOs and pipes. Services and actions receive valid, typed values.
- Path ids: `@Param('<entity>Id', new ParseUUIDPipe({ errorHttpStatusCode: HttpStatus.NOT_FOUND }))` — a malformed id is `404`, like a missing one.
- Return type annotated with the endpoint's `*ResDto` or the shared DTO.
- Map domain data to the response with a static DTO factory: `WordDto.fromWord(word)`.

## DTOs

- Every DTO is a class named `*Dto` with class-validator decorators on its fields — response DTOs too.
- One dto file per endpoint: `dto/<verb>-<entity>.dto.ts` with `<Verb><Entity>ReqDto` (if it has a body or query) and `<Verb><Entity>ResDto` only when the response differs from a shared DTO. Otherwise the endpoint returns the shared DTO (`dto/<entity>.dto.ts`) — no empty `extends <Entity>Dto {}`.
- Derive from the entity's model class with `PickType` / `OmitType` / `PartialType` / `IntersectionType` (keys `as const`); add only fields the model lacks.
- A DTO is built only through its own static factory (`<Entity>Dto.from<Entity>(…)`, `ApiErrorDto.of(…)`), with `Object.assign(new <Entity>Dto(), { … })`; it converts types the wire needs (`Date` → ISO string). No free functions that build DTOs.
- Services never import `dto/`; they take inputs from `*.types.ts` or model `Pick`s and return domain data. No `*View` types.

## Versioning

- URI versioning, set up in `src/app.setup.ts` with default version `1`; infra controllers (`/healthz`, `/webhooks/*`) are `VERSION_NEUTRAL`.
- New major: unchanged controllers serve both (`version: ['1', '2']`); changed ones get one controller per version (`<entity>-v1.controller.ts`, `<entity>-v2.controller.ts`), or `@Version` per method when only some routes change.

## Transactions

- No tx parameters. Mark the method that owns the transaction `@Transactional()`; inside, use `txHost.tx` (`@InjectTransactionHost()` in services).
- A service method that must run inside the caller's transaction: `@Transactional(Propagation.Mandatory)`.
- Options (isolation level) go in the decorator: `@Transactional<Adapter>({ isolationLevel: 'repeatable read' })`.

## Checklist

```
- [ ] Command/query + handler in one src/actions/ file, class name = file name
- [ ] Fields on the command (`readonly <field>: <type>;`, no `declare`), CommandProps constructor, no input interface
- [ ] Handler registered in ActionsModule
- [ ] Controller: bus for actions, service for plain CRUD, *ResDto or shared DTO return type
- [ ] Validation and conversion only at the controller edge (DTOs, pipes); ParseUUIDPipe with 404
- [ ] One dto file per endpoint; *ResDto only when it differs from a shared DTO; derived via mapped-types; decorators on every field
- [ ] DTOs built only through their own static factory
- [ ] Services never import dto/, no *View types
- [ ] @Transactional + txHost.tx, Propagation.Mandatory for caller-tx-only methods, no tx parameters
```
