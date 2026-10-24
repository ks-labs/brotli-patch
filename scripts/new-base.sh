#!/bin/sh
# Cria a pasta e o workflow de uma nova base (Dockerfile + .github/workflows/<pasta>.yml).
#
# uso: scripts/new-base.sh <pasta> <imagem-base> <tag-publicada> <caminho-do-node> <versao-do-node>
# ex.: scripts/new-base.sh node-18.20.8-slim node:18.20.8-slim 18.20.8-slim-brotli-patch /usr/local/bin/node 18.20.8
#
# Use a tag EXATA da base (ex.: node:18.20.8-slim, nunca node:18-slim): o binário
# publicado só é seguro de usar sobre a mesma versão do Node.js.
set -eu

if [ "$#" -ne 5 ]; then
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi

DIR=$1
BASE=$2
TAG=$3
NPATH=$4
EXPECT=$5

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -e "$ROOT/$DIR" ] && { echo "A pasta '$DIR' já existe." >&2; exit 1; }
mkdir -p "$ROOT/$DIR" "$ROOT/.github/workflows"

cat > "$ROOT/$DIR/Dockerfile" <<EOF
# syntax=docker/dockerfile:1
#
# Binário do Node.js ${EXPECT} com o Brotli corrigido (CVE-2026-111497).
# Base original: ${BASE}
#
# image: ghcr.io/ks-labs/node
# tag:   ${TAG}
#
# O contexto de build é a raiz do repositório:
#   docker build -f ${DIR}/Dockerfile -t node-brotli-patch .
ARG BASE=${BASE}
ARG EXPECT_NODE=${EXPECT}
ARG NODE_PATH=${NPATH}

# 1) Compila o mesmo Node da base com o Brotli corrigido.
FROM \${BASE} AS build
ARG BASE
ENV BASE_IMAGE=\${BASE}
COPY common/build-node.sh common/brotli-v1.0.9-to-v1.0.10.patch common/brotli-v1.1.0-to-v1.1.1.patch /patches/
RUN sed -i 's/\\r\$//' /patches/* && sh /patches/build-node.sh

# 2) Verifica DENTRO da base original, com o binário corrigido no lugar.
FROM \${BASE} AS verify
ARG EXPECT_NODE
ARG NODE_PATH
COPY --from=build /node \${NODE_PATH}
COPY common/verify.js /tmp/verify.js
RUN test "\$(node -p process.versions.node)" = "\${EXPECT_NODE}" && node /tmp/verify.js

# 3) Artefato final: somente o binário (e licença/metadados), sem sistema operacional.
FROM scratch
ARG NODE_PATH
COPY --from=verify \${NODE_PATH} /node
COPY --from=build /NODE-LICENSE /build-info.json /
LABEL org.opencontainers.image.title="Node.js ${EXPECT} com Brotli corrigido (CVE-2026-111497)" \\
      org.opencontainers.image.description="Somente o binário do node ${EXPECT}, compilado com o decoder Brotli corrigido. Não é uma distribuição oficial do Node.js." \\
      org.opencontainers.image.source="https://github.com/ks-labs/brotli-patch" \\
      org.opencontainers.image.licenses="MIT" \\
      org.opencontainers.image.version="${TAG}"
EOF

cat > "$ROOT/.github/workflows/$DIR.yml" <<EOF
name: ${DIR}

# Compila em paralelo (um runner por pasta) e publica o binário corrigido desta base.
# Dispara quando algo da pasta, do código comum ou do workflow reutilizável muda.
on:
  push:
    branches: [main]
    paths:
      - '${DIR}/**'
      - 'common/**'
      - '.github/workflows/_build.yml'
      - '.github/workflows/${DIR}.yml'
  workflow_dispatch:
    inputs:
      force:
        description: Recompilar mesmo que a tag já exista no registro
        type: boolean
        default: false

concurrency:
  group: build-${DIR}
  cancel-in-progress: false

jobs:
  build:
    uses: ./.github/workflows/_build.yml
    with:
      folder: ${DIR}
      force: \${{ inputs.force || false }}
    permissions:
      contents: read
      packages: write
      id-token: write
      attestations: write
EOF

echo "Criado: $DIR/Dockerfile e .github/workflows/$DIR.yml"
echo "Adicione a base à tabela do README e abra o pull request."
