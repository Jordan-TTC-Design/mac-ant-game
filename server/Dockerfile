# syntax=docker/dockerfile:1.7

# 後端（Hono + PostgreSQL）— docker-compose*.yml 的 server 服務。build context 是 repo 最上層（pnpm workspace，要用到 shared/）。
# 用 tsx 直接跑 TypeScript（量不大，不另外打包）；資料庫 migration 在每次啟動時自動套用。

FROM node:22-alpine
WORKDIR /repo
ENV NODE_ENV=production
RUN npm install -g pnpm@12.6.0

# 相依只跟 package.json / lockfile 有關，改原始碼不會重跑這一層
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.base.json ./
COPY shared/package.json shared/
COPY server/package.json server/
COPY pwa/package.json pwa/
RUN --mount=type=cache,target=/root/.local/share/pnpm/store,sharing=locked \
    pnpm install --frozen-lockfile --prod --ignore-scripts --filter @goblincamp/server...

COPY shared/src shared/src
COPY server/src server/src
COPY server/drizzle server/drizzle

WORKDIR /repo/server
USER node
EXPOSE 8787
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8787/api/health >/dev/null 2>&1 || exit 1
CMD ["node", "--import", "tsx", "src/index.ts"]
