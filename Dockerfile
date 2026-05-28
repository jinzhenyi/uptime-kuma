# 精简版 Dockerfile - 仅构建 Uptime Kuma 运行镜像，保留端口 3001

ARG BASE_IMAGE=louislam/uptime-kuma:base2

############################################
# Build in Golang (健康检查工具)
############################################
FROM louislam/uptime-kuma:builder-go AS build_healthcheck

############################################
# Build in Node.js (应用构建)
############################################
FROM louislam/uptime-kuma:base2 AS build

# 以 root 身份预先创建目录并授权
USER root
RUN mkdir -p /app && chown -R node:node /app
RUN mkdir -p /app/data && chown node:node /app/data

USER node
WORKDIR /app

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1
COPY --chown=node:node .npmrc .npmrc
COPY --chown=node:node package.json package.json
COPY --chown=node:node package-lock.json package-lock.json
RUN npm ci --omit=dev
COPY . .
COPY --chown=node:node --from=build_healthcheck /app/extra/healthcheck /app/extra/healthcheck
# data 目录已预先创建，无需再 mkdir

############################################
# ⭐ 最终运行镜像
############################################
FROM $BASE_IMAGE AS release
WORKDIR /app

LABEL org.opencontainers.image.source="https://github.com/louislam/uptime-kuma"

ENV UPTIME_KUMA_IS_CONTAINER=1

# 从 build 阶段复制全部应用文件
COPY --chown=node:node --from=build /app /app

# 暴露默认端口 3001（保持原样）
EXPOSE 3001

HEALTHCHECK --interval=60s --timeout=30s --start-period=180s --retries=5 CMD extra/healthcheck
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "server/server.js"]