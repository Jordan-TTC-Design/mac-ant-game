# syntax=docker/dockerfile:1.7

# 手機網頁（Nuxt 4，純前端）＋ nginx — docker-compose*.yml 的 web 服務。build context 是 repo 最上層
# （pnpm workspace，要用到 shared/，還有 Mac 的角色圖、營地圖、裝飾圖、公會的角色與據點圖，以及魔獸的掉落物名稱）。nginx 送出靜態檔，並把 /api（含 WebSocket）轉給 server。

# ---------- build ----------
FROM node:22-alpine AS build
WORKDIR /repo
ENV NUXT_TELEMETRY_DISABLED=1
RUN npm install -g pnpm@12.6.0

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.base.json ./
COPY shared/package.json shared/
COPY server/package.json server/
COPY pwa/package.json pwa/
# postinstall 的 nuxt prepare 這時還沒有原始碼，先跳過，交給 nuxt generate 自己準備
RUN --mount=type=cache,target=/root/.local/share/pnpm/store,sharing=locked \
    pnpm install --frozen-lockfile --ignore-scripts --filter @goblincamp/pwa...

COPY shared/src shared/src
COPY pwa pwa
COPY mac/Resources/Characters mac/Resources/Characters
COPY mac/Resources/Camps mac/Resources/Camps
COPY mac/Resources/Animals mac/Resources/Animals
COPY mac/Resources/World mac/Resources/World
COPY mac/Resources/Terrain mac/Resources/Terrain
COPY mac/Resources/Decor mac/Resources/Decor
COPY mac/Resources/Avatars mac/Resources/Avatars
COPY mac/Resources/Guild mac/Resources/Guild
RUN pnpm --filter @goblincamp/pwa build

# ---------- runtime ----------
FROM nginx:alpine
COPY docker-setting/nginx/web.conf /etc/nginx/conf.d/default.conf
COPY --from=build /repo/pwa/.output/public /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1
