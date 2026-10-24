#!/bin/sh
# Compila o MESMO Node.js da imagem base com o Brotli embutido corrigido
# (CVE-2026-111497, "Node2Shell"). Produz:
#   /node               binário do node (strip)
#   /NODE-LICENSE       licença do Node.js, exigida na redistribuição do binário
#   /build-info.json    versões, hashes e origem do build (rastreabilidade)
#
# Linhas de Node em fim de vida não recebem correção oficial. O Google publicou o
# conserto do decoder nos releases de manutenção 1.0.10 e 1.1.1 do Brotli. Aqui o
# diff 1.0.9->1.0.10 (ou 1.1.0->1.1.1), restrito a c/ do Brotli, é aplicado sobre o
# deps/brotli do próprio Node. Nada mais muda: mesma versão do Node, mesmas flags
# de configure do build oficial. Veja o README do repositório.
set -eu

PATCHES=/patches

# Falhas temporárias de rede/DNS são comuns em CI; repete até 5 vezes.
retry() {
  n=0
  until "$@"; do
    n=$((n + 1))
    [ "$n" -ge 5 ] && return 1
    echo "tentativa $n falhou; repetindo..." >&2
    sleep 10
  done
}

# Dependências de compilação (só neste estágio; não vão para o artefato final).
if command -v apk >/dev/null 2>&1; then
  FAMILY=musl
  retry apk add --no-cache build-base python3 linux-headers curl xz patch coreutils
else
  FAMILY=glibc
  # Debian bullseye foi arquivado; o repositório oficial passou a dar 404.
  if grep -q 'VERSION_CODENAME=bullseye' /etc/os-release; then
    printf 'deb http://archive.debian.org/debian bullseye main\ndeb http://archive.debian.org/debian-security bullseye-security main\n' > /etc/apt/sources.list
    rm -f /etc/apt/sources.list.d/*
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99archive
  fi
  retry apt-get update
  retry apt-get install -y --no-install-recommends build-essential python3 curl ca-certificates xz-utils patch
  rm -rf /var/lib/apt/lists/*
fi

# A versão a compilar é a da própria imagem base (nunca fixada à mão).
V="$(node -p 'process.versions.node')"
B="$(node -p 'process.versions.brotli')"
case "$B" in
  1.0.9) FIXED=1.0.10; P=brotli-v1.0.9-to-v1.0.10.patch ;;
  1.1.0) FIXED=1.1.1;  P=brotli-v1.1.0-to-v1.1.1.patch ;;
  *) echo "Brotli $B da imagem base não tem patch conhecido; abortando." >&2; exit 1 ;;
esac
echo "Node v$V (Brotli $B) -> Brotli $FIXED [$FAMILY]"

# Os binários musl oficiais (Alpine) vêm do unofficial-builds; os demais, do nodejs.org.
# O valor entra em process.config e é usado pelo node-gyp para baixar headers.
if [ "$FAMILY" = musl ]; then
  URLBASE=https://unofficial-builds.nodejs.org/download/release/
else
  URLBASE=https://nodejs.org/download/release/
fi

mkdir /src && cd /src
retry curl -fsSLO "https://nodejs.org/dist/v$V/node-v$V.tar.xz"
retry curl -fsSLO "https://nodejs.org/dist/v$V/SHASUMS256.txt"
grep " node-v$V.tar.xz\$" SHASUMS256.txt | sha256sum -c -
SRC_SHA="$(grep " node-v$V.tar.xz\$" SHASUMS256.txt | cut -d' ' -f1)"
tar -xJf "node-v$V.tar.xz" --strip-components=1
rm "node-v$V.tar.xz"

patch -p1 --dry-run < "$PATCHES/$P"
patch -p1 < "$PATCHES/$P"
PATCH_SHA="$(sha256sum "$PATCHES/$P" | cut -d' ' -f1)"

./configure --release-urlbase="$URLBASE"
make -j"$(nproc)"

./out/Release/node -e "
  const v = process.versions;
  if (v.node !== '$V' || v.brotli !== '$FIXED') { console.error(JSON.stringify(v)); process.exit(1); }"
strip out/Release/node
cp out/Release/node /node
cp LICENSE /NODE-LICENSE
NODE_SHA="$(sha256sum /node | cut -d' ' -f1)"

cat > /build-info.json <<EOF
{
  "node": "$V",
  "brotliBefore": "$B",
  "brotliAfter": "$FIXED",
  "libc": "$FAMILY",
  "baseImage": "${BASE_IMAGE:-unknown}",
  "nodeSourceSha256": "$SRC_SHA",
  "patch": "$P",
  "patchSha256": "$PATCH_SHA",
  "nodeBinarySha256": "$NODE_SHA",
  "cve": "CVE-2026-111497"
}
EOF
cat /build-info.json
