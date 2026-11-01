# syntax=docker/dockerfile:1
FROM docker.io/library/node:26.13-trixie-slim AS base
ENV CI=true
RUN npm install -g pnpm@12.16.1 \
 && mkdir -p /app /pnpm-store \
 && chown -R node:node /app /pnpm-store
USER node
WORKDIR /app

FROM base AS deps
COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
RUN --mount=type=cache,id=pnpm-store,target=/pnpm-store,uid=1000,gid=1000 \
    pnpm install --frozen-lockfile

# dev: source and node_modules come from the bind mount; `make install` fills node_modules
FROM base AS dev
COPY --chown=node:node package.json pnpm-workspace.yaml .npmrc ./
CMD ["pnpm", "dev"]

FROM deps AS build
COPY --chown=node:node . .
RUN pnpm build

FROM base AS prod
ENV NODE_ENV=production
COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
RUN --mount=type=cache,id=pnpm-store,target=/pnpm-store,uid=1000,gid=1000 \
    pnpm install --frozen-lockfile --prod
COPY --from=build --chown=node:node /app/dist ./dist
COPY --chown=node:node drizzle ./drizzle
CMD ["node", "dist/main.js"]
