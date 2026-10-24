# syntax=docker/dockerfile:1
#
# Binário do Node.js 14.21.3 com o Brotli corrigido (CVE-2026-111497).
# Base original: nikolaik/python-nodejs:python3.11-nodejs14-slim
#
# image: ghcr.io/ks-labs/node
# tag:   14.21.3-bullseye-brotli-patch
#
# O contexto de build é a raiz do repositório:
#   docker build -f python-nodejs-python3.11-nodejs14-slim/Dockerfile -t node-brotli-patch .
ARG BASE=nikolaik/python-nodejs:python3.11-nodejs14-slim
ARG EXPECT_NODE=14.21.3
ARG NODE_PATH=/usr/bin/node

# 1) Compila o mesmo Node da base com o Brotli corrigido.
FROM ${BASE} AS build
ARG BASE
ENV BASE_IMAGE=${BASE}
COPY common/build-node.sh common/brotli-v1.0.9-to-v1.0.10.patch common/brotli-v1.1.0-to-v1.1.1.patch /patches/
RUN sed -i 's/\r$//' /patches/* && sh /patches/build-node.sh

# 2) Verifica DENTRO da base original, com o binário corrigido no lugar.
FROM ${BASE} AS verify
ARG EXPECT_NODE
ARG NODE_PATH
COPY --from=build /node ${NODE_PATH}
COPY common/verify.js /tmp/verify.js
RUN test "$(node -p process.versions.node)" = "${EXPECT_NODE}" && node /tmp/verify.js

# 3) Artefato final: somente o binário (e licença/metadados), sem sistema operacional.
FROM scratch
ARG NODE_PATH
COPY --from=verify ${NODE_PATH} /node
COPY --from=build /NODE-LICENSE /build-info.json /
LABEL org.opencontainers.image.title="Node.js 14.21.3 com Brotli corrigido (CVE-2026-111497)" \
      org.opencontainers.image.description="Somente o binário do node 14.21.3, compilado com o decoder Brotli corrigido. Não é uma distribuição oficial do Node.js." \
      org.opencontainers.image.source="https://github.com/ks-labs/brotli-patch" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="14.21.3-bullseye-brotli-patch"
