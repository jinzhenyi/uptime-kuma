ARG BASE_IMAGE=louislam/uptime-kuma:base2

############################################
# Build in Golang
############################################
FROM louislam/uptime-kuma:builder-go AS build_healthcheck

############################################
# Build in Node.js
############################################
FROM louislam/uptime-kuma:base2 AS build

USER root
RUN mkdir -p /app && chown -R node:node /app
RUN mkdir -p /app/data && chown node:node /app/data

USER node
WORKDIR /app

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1
COPY --chown=node:node .npmrc .npmrc
COPY --chown=node:node package.json package.json
COPY --chown=node:node package-lock.json package-lock.json
# 需要 devDependencies 来执行构建，所以去掉 --omit=dev
RUN npm ci
COPY . .
# 关键：构建前端
RUN npm run build
COPY --chown=node:node --from=build_healthcheck /app/extra/healthcheck /app/extra/healthcheck
# data 目录已预先创建

############################################
# ⭐ 最终运行镜像
############################################
FROM $BASE_IMAGE AS release
WORKDIR /app

LABEL org.opencontainers.image.source="https://github.com/louislam/uptime-kuma"
ENV UPTIME_KUMA_IS_CONTAINER=1

COPY --chown=node:node --from=build /app /app

EXPOSE 3001
HEALTHCHECK --interval=60s --timeout=30s --start-period=180s --retries=5 CMD extra/healthcheck
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "server/server.js"]