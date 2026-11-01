---
name: dev-environment
description: Containerized dev environment — compose.yaml, Dockerfile, Makefile, package manager, dependency versions. Use any time a project command is run (install, dev, test, lint, typecheck, migrate, add a dependency) and any time the dev environment or dependencies are set up or changed.
---

# Dev environment

## Running commands

- Everything runs in `compose.yaml` through the `Makefile`. Never run `pnpm`, `node`, `npx` or `docker compose` directly.
- A one-off package-manager command: `make pnpm ARGS="<args>"` (e.g. `ARGS="add <pkg>"`).
- A command you need repeatedly has no target → add a target to the `Makefile`.
- Done means `make check` is clean (format check, typecheck, lint, unit, e2e).

## Dependencies

- Latest stable versions of everything: runtime image, package manager, every dependency. Check the registry (`make pnpm ARGS="view <pkg> version"`), never from memory. A pre-release only when the project chose it.
- pnpm, pinned via `packageManager` in `package.json` and the same version in the `Dockerfile` and `Makefile`.

## Containers

- The pnpm store is a named volume (`pnpm-store`), set in `pnpm-workspace.yaml` (`storeDir: /pnpm-store`, `packageImportMethod: copy`).
- `node_modules` is never copied into an image (`.dockerignore`). It is installed in the project dir, inside the container, by `make install`; the dev stage copies only manifests and gets the source by bind mount.
- Container user = host user, root on rootless Docker/Podman (`CONTAINER_USER` in the `Makefile`), so files in the bind mount keep the host owner.
- Ports bound to `127.0.0.1`. The DB has a healthcheck; the app `depends_on` it with `service_healthy`.

## Templates

Starting point for a new project; replace `<app>` and versions with the latest, keep the structure.

- [templates/Makefile](templates/Makefile) — targets: `help build lockfile install up down dev logs shell pnpm typecheck lint lint-fix fmt fmt-check test test-e2e db-generate db-generate-custom db-migrate check clean`
- [templates/compose.yaml](templates/compose.yaml)
- [templates/Dockerfile](templates/Dockerfile) — stages `base`, `deps`, `dev`, `build`, `prod`
- [templates/pnpm-workspace.yaml](templates/pnpm-workspace.yaml)
- [templates/.dockerignore](templates/.dockerignore)

First run: `make lockfile` → `make build` → `make install` → `make up`.

## Checklist

```
- [ ] Every command via make; missing one → new Makefile target
- [ ] Latest versions, checked in the registry
- [ ] pnpm store in a named volume; node_modules not in any image
- [ ] make check clean
```
