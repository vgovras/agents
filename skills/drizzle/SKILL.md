---
name: drizzle
description: Drizzle ORM rules — table schemas, model classes, relations, enums in the DB, relational queries vs query builder, migrations. Use any time Drizzle code is written or changed — a table, relation, query, transaction or migration.
---

# Drizzle

Drizzle 1.x (RC) with relations v2 (`defineRelations`). Verify APIs via context7 against the v2 docs — v1 examples (`relations()`, callback `where`) are outdated.

## Files

- Table: `<entity>.schema.ts` (`schemas/` when the module has 2+). The row type lives next to the table:
  ```ts
  export type I<Entity>Row = typeof <entities>.$inferSelect;
  ```
- Model: `<entity>.model.ts` (`models/` when 2+), `export class <Entity>Model implements I<Entity>Row`. Validation decorators only on fields a DTO derives.
- All relations in `src/db.relations.ts` with `defineRelations`; it also exports the app DB and transaction-host types (`AppDb`, `AppTransactionHost`).
- A schema is private to its module; only actions (for their own data access) and `src/db.relations.ts` import it from outside. Other modules import the model.

## Columns

- Value sets: `varchar({ length: <MAX> }).$type<<Enum>>()`. No PG enums.

## Queries

| Need | API |
|---|---|
| Read — one table or with relations | relational queries: `tx.query.<table>.findFirst` / `findMany` + `with`, object `where` |
| Write (insert, update, delete, upsert) | query builder |
| Row lock | query builder `.for('update')` |
| Aggregate (`count`, `max`) | query builder |
| Complex condition (`or`, `ilike`, subquery) | query builder |
| Bulk operation | query builder |

- Always through `txHost.tx`, never the injected DB instance (skill `nestjs` › Transactions).

## Migrations

- Generated from the schema by drizzle-kit through the project's command runner (skill `dev-environment`); custom SQL only through an empty generated migration.

## Checklist

```
- [ ] Table in *.schema.ts, I<Entity>Row = $inferSelect, model implements it
- [ ] Relations only in src/db.relations.ts (defineRelations)
- [ ] Enums: varchar + $type<Enum>(), no pgEnum
- [ ] Reads via tx.query + with; writes, locks, aggregates, complex and bulk via query builder
- [ ] Every query through txHost.tx
- [ ] Migration generated, not hand-written
```
