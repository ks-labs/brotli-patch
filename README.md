# brotli-patch

Binários do **Node.js em fim de vida** recompilados com o **decoder Brotli corrigido**
([CVE-2026-111497](https://security-tracker.debian.org/tracker/CVE-2026-111497),
apelidado de *Node2Shell*), para quem ainda roda Node.js 14 ou 20 e não consegue
migrar agora.

> **Aviso.** Projeto **não oficial**, sem afiliação com o OpenJS Foundation nem com o
> Node.js, mantido em regime de melhor esforço e **sem SLA**. Ele corrige **apenas**
> o CVE-2026-111497. A solução definitiva é migrar para um Node.js suportado.
> Leia [Limitações](#limitações-e-não-objetivos) antes de usar em produção.

## Resumo

- A falha é uma escrita fora dos limites no decoder Brotli que vem **compilado dentro
  do binário `node`**. Nenhum pacote npm, variável de ambiente ou atualização do
  sistema operacional corrige isso: só trocar o binário.
- O Node.js corrigiu as linhas 22, 24 e 26. As linhas **20 e anteriores não recebem
  correção** (fim de vida).
- Este repositório publica, para cada base, uma imagem `FROM scratch` com **somente o
  `node` corrigido**, **na mesma versão** do Node.js que você já usa.
- Você mantém a sua imagem base (e as atualizações do sistema operacional dela) e
  acrescenta **uma linha** ao Dockerfile:

```dockerfile
FROM node:14.21.3-alpine
COPY --from=ghcr.io/ks-labs/node:14.21.3-alpine-brotli-patch /node /usr/local/bin/node
```

## English summary

Node.js releases before 22.23.4, 24.22.1 and 26.12.1 contain an out-of-bounds write
in the bundled Brotli decoder (CVE-2026-111497). Upstream does not patch end-of-life
lines (20 and older). This repository builds the **exact same Node.js version** from
source with the upstream Brotli fix (v1.0.10 / v1.1.1) applied to `deps/brotli`, and
publishes only the resulting `node` binary as a `FROM scratch` image on GHCR, so you
can `COPY --from=` it over the binary in your existing base image. It is unofficial,
best-effort, fixes only this CVE, and is a stop-gap: migrate to a supported Node.js.

## Índice

- [O problema](#o-problema)
- [Imagens disponíveis](#imagens-disponíveis)
- [Como usar](#como-usar)
- [Como funciona](#como-funciona)
- [Verificação e cadeia de suprimentos](#verificação-e-cadeia-de-suprimentos)
- [Garantias de compatibilidade](#garantias-de-compatibilidade)
- [Limitações e não objetivos](#limitações-e-não-objetivos)
- [Plano de saída: migrar de verdade](#plano-de-saída-migrar-de-verdade)
- [Pedindo ou adicionando uma base](#pedindo-ou-adicionando-uma-base)
- [Manutenção e suporte](#manutenção-e-suporte)
- [Licença e créditos](#licença-e-créditos)
- [Referências](#referências)

## O problema

| | |
|---|---|
| **Identificador** | CVE-2026-111497 ("Node2Shell") |
| **Componente** | Decoder do Brotli embutido no Node.js (`deps/brotli`) |
| **Tipo** | Escrita fora dos limites (*out-of-bounds write*) ao decodificar um stream malformado, com potencial de execução de código |
| **Divulgação** | Release de segurança do Node.js de 21/10/2026 |
| **Corrigido em** | Node.js 22.23.4, 24.22.1 e 26.12.1 |
| **Sem correção** | Linhas em fim de vida: 20.x e anteriores (e 23.x, 25.x) |
| **Severidade** | O Node.js classifica como *High*; o registro do CVE traz CVSS 4.0 de 9,2. A classificação é disputada entre as fontes |

**Causa.** O decoder não rejeitava cedo um stream que declara um único tipo de bloco e
mesmo assim tenta trocar de bloco. O conserto upstream é o commit
[`google/brotli@0ed4268a`](https://github.com/google/brotli/commit/0ed4268a) ("Detect
and report invalid stream earlier"), publicado nos releases de manutenção
**Brotli 1.0.10, 1.1.1 e 1.2.1**. O Node.js fez *cherry-pick* disso nas linhas
suportadas.

**Quem está exposto.** Qualquer processo que **decodifique Brotli vindo de uma origem
não confiável**: `zlib.brotliDecompress*`, `zlib.createBrotliDecompress`, respostas
HTTP com `Content-Encoding: br` (por exemplo via `fetch()` no Node 18+ ou clientes que
anunciam `br` em `Accept-Encoding`) e corpos de requisição `br` aceitos por
frameworks. Se a sua aplicação nunca decodifica Brotli, o risco prático é menor, mas
**confirme na sua base de código** em vez de presumir.

Por que não basta atualizar o sistema operacional: o Node.js distribui o Brotli
**estaticamente ligado** ao binário. Atualizar `libbrotli` do sistema não altera o
`node`.

## Imagens disponíveis

Registro: `ghcr.io/ks-labs/node`. Plataforma: **`linux/amd64`**.

| Tag | Base original (tag exata) | Node.js | Brotli | libc |
|---|---|---|---|---|
| `14.21.3-alpine-brotli-patch` | `node:14.21.3-alpine` | 14.21.3 | 1.0.9 → **1.0.10** | musl |
| `14.19.3-alpine-brotli-patch` | `node:14.19.3-alpine` | 14.19.3 | 1.0.9 → **1.0.10** | musl |
| `14.21.3-bullseye-brotli-patch` | `nikolaik/python-nodejs:python3.11-nodejs14-slim` (Debian 11) | 14.21.3 | 1.0.9 → **1.0.10** | glibc 2.31 |
| `20.11.1-slim-brotli-patch` | `node:20.11.1-slim` (Debian 12) | 20.11.1 | 1.0.9 → **1.0.10** | glibc 2.36 |
| `20.20.2-alpine-brotli-patch` | `node:20.20.2-alpine` | 20.20.2 | 1.1.0 → **1.1.1** | musl |

Cada imagem contém apenas três arquivos:

| Arquivo | Conteúdo |
|---|---|
| `/node` | O binário corrigido |
| `/NODE-LICENSE` | Licença do Node.js (exigida na redistribuição) |
| `/build-info.json` | Versões, base, patch aplicado e SHA-256 do fonte, do patch e do binário |

**Escolha pela libc.** Use a imagem cuja libc seja **igual ou mais antiga** que a da sua
base. O binário `glibc 2.36` não roda em uma base com glibc 2.31; o contrário funciona.
Alpine (musl) e Debian (glibc) não são intercambiáveis.

A tag precisa casar com a **versão exata** do Node.js da sua imagem. Dependências
nativas já compiladas (`node_modules/**/*.node`) dependem da ABI, e a versão do
binário precisa ser a mesma para que continuem válidas.

## Como usar

### 1. Imagem de aplicação

Mantenha a sua base **com a tag exata** e copie o binário por cima:

```dockerfile
FROM node:20.11.1-slim

COPY --from=ghcr.io/ks-labs/node:20.11.1-slim-brotli-patch /node /usr/local/bin/node

# Recomendado: o build falha se a base mudar de versão ou se o patch não estiver ativo.
RUN test "$(node -p process.versions.node)" = "20.11.1" \
 && test "$(node -p process.versions.brotli)" = "1.0.10"

# ... o resto do seu Dockerfile, sem alterações
```

Imagens `nikolaik/python-nodejs` guardam o binário em `/usr/bin/node`:

```dockerfile
FROM nikolaik/python-nodejs:python3.11-nodejs14-slim
COPY --from=ghcr.io/ks-labs/node:14.21.3-bullseye-brotli-patch /node /usr/bin/node
```

Descubra o caminho na sua base com `docker run --rm <base> sh -c 'command -v node'`.

### 2. Multi-stage

Aplique a troca **em todo estágio em que o Node.js roda em produção**. Estágios que só
geram arquivos estáticos para outro servidor (por exemplo, `npm run build` e depois
`nginx`) não executam o decoder em tráfego real, então a troca é opcional neles.

### 3. Confirmando na imagem final

```sh
docker run --rm sua-imagem node -p "process.version + ' brotli ' + process.versions.brotli"
# v20.11.1 brotli 1.0.10
```

Um valor `1.0.9` ou `1.1.0` significa que o binário original continua em uso.

## Como funciona

```
base original ──► [build]  mesma versão do Node.js + patch do Brotli ──► compila
                     │
                     ▼
base original ──► [verify] coloca o binário novo e roda common/verify.js
                     │       (se falhar, nada é publicado)
                     ▼
                  [scratch] /node  /NODE-LICENSE  /build-info.json ──► ghcr.io
```

1. **Lê a versão da própria base.** `build-node.sh` executa `node -p process.versions.*`
   dentro da imagem base. A versão do Node.js nunca é digitada à mão, então não há
   deriva entre "o que o sistema usa" e "o que foi compilado".
2. **Baixa o código-fonte oficial** em `nodejs.org/dist` e confere o **SHA-256** contra
   o `SHASUMS256.txt` da mesma versão.
3. **Aplica o diff do Brotli.** Os arquivos `common/brotli-*.patch` são o diff oficial do
   google/brotli (`v1.0.9..v1.0.10` ou `v1.1.0..v1.1.1`), restrito ao diretório `c/` e
   remapeado para `deps/brotli/c/` do Node.js. São cerca de 60 linhas em `decode.c`. O
   script escolhe o patch pela versão de Brotli que a base já tem e **aborta** se não
   houver patch conhecido.
4. **Compila com as mesmas flags do binário oficial** (`./configure`, sem opções
   extras, exceto `--release-urlbase`, que replica o valor do binário original).
5. **Verifica dentro da base original** (`common/verify.js`), com o binário novo no
   lugar:
   - o Node.js tem a versão esperada e o Brotli é `1.0.10` ou `1.1.1`;
   - *roundtrip* de compressão e descompressão Brotli em vários tamanhos e níveis;
   - o stream de regressão do próprio Node.js para este CVE é **rejeitado** com
     `BLOCK_SWITCH`;
   - `gzip` e `deflate` continuam funcionando.
6. **Publica** somente o binário em uma imagem `FROM scratch`, com atestados de
   proveniência e SBOM.

Um workflow por pasta (`.github/workflows/<pasta>.yml`) compila cada base **em paralelo,
em um runner próprio**, e **pula** a compilação se a tag já existe no registro. Para
recompilar, dispare o workflow manualmente com `force`.

## Verificação e cadeia de suprimentos

Não confie cegamente em um binário de terceiros. Tudo aqui é auditável:

- **Código aberto e CI público.** O build roda em GitHub Actions neste repositório; os
  logs são públicos.
- **Metadados dentro da imagem.** Inspecione o `/build-info.json`:

  ```sh
  docker create --name bp ghcr.io/ks-labs/node:14.21.3-alpine-brotli-patch /node
  docker cp bp:/build-info.json - | tar -xO
  docker rm bp
  ```

- **Proveniência e SBOM** (BuildKit, anexados à imagem):

  ```sh
  docker buildx imagetools inspect ghcr.io/ks-labs/node:14.21.3-alpine-brotli-patch --format '{{ json .Provenance }}'
  docker buildx imagetools inspect ghcr.io/ks-labs/node:14.21.3-alpine-brotli-patch --format '{{ json .SBOM }}'
  ```

- **Reprodutibilidade.** Rode o mesmo Dockerfile localmente
  (`docker build -f <pasta>/Dockerfile .`) e compare as versões e o patch aplicado
  com o `build-info.json`. O hash do binário **não** é idêntico bit a bit entre
  builds (o Node.js não garante builds reproduzíveis bit a bit), mas as versões, o
  fonte e o patch são.
- **Fixe por digest** se precisar de imutabilidade: `ghcr.io/ks-labs/node@sha256:...`.

Limite honesto: o SHA-256 do código-fonte é conferido contra o `SHASUMS256.txt`
publicado em `nodejs.org`, **sem** verificar a assinatura GPG desse arquivo. Isso
protege contra corrupção, mas não contra um comprometimento do próprio `nodejs.org`.

## Garantias de compatibilidade

O objetivo é **zero divergência de comportamento** em relação ao binário oficial da
mesma versão, exceto o conserto do Brotli. O que foi comparado entre o binário
oficial e o corrigido, na imagem base original:

- `process.versions` (todas as versões, **exceto** `brotli`), `process.features`,
  suporte a ICU e versão do OpenSSL;
- toda a configuração de build em `process.config.variables`;
- `npm` e execução normal na imagem original com o binário trocado.

Diferenças conhecidas e esperadas:

| Diferença | Detalhe |
|---|---|
| `process.versions.brotli` | É o objetivo: `1.0.9 → 1.0.10` ou `1.1.0 → 1.1.1` |
| Tamanho do binário | Alguns MiB menor, porque o binário é *stripped* |
| Hash do binário | Diferente do oficial (é uma recompilação) |
| `process.config` | Nos binários musl, o `node_section_ordering_info` do build do Alpine não aparece; não tem efeito funcional |

Não prometemos nada além do que está listado. Se você achar uma divergência, abra uma
issue com a tag e o comando que a reproduz.

## Limitações e não objetivos

- **Corrige somente o CVE-2026-111497.** Qualquer outra vulnerabilidade do Node.js,
  do V8, do OpenSSL ou de outras dependências em versões sem suporte **continua
  presente**. O CVE-2026-111497 foi publicado junto de outros nove no mesmo release de
  segurança, e este projeto não os corrige.
- **Não é uma distribuição oficial** nem substitui o suporte do Node.js.
- **Só `linux/amd64`.**
- **Só as bases listadas.** Outras podem ser pedidas (veja abaixo).
- **Sem atualização automática de versões do Node.js.** As versões são congeladas,
  pois as linhas já estão em fim de vida.
- **Exige confiança no mantenedor do binário.** Veja a seção de verificação para
  reduzir essa confiança.
- **Não é um plano de longo prazo.** Use enquanto planeja a migração.

## Plano de saída: migrar de verdade

A correção sustentável é executar uma versão do Node.js que ainda recebe patches:
**22.23.4**, **24.22.1** ou **26.12.1**, ou superior. Sugestão de caminho para quem
está em versões antigas:

1. Suba a aplicação em um Node.js suportado em um ambiente de teste e rode a suíte.
2. Atualize dependências nativas (`node-sass`, `bcrypt`, `sharp` e similares), que são
   o ponto de quebra mais comum entre majors.
3. Troque o `FROM` para a imagem oficial e **remova** a linha `COPY --from=...-brotli-patch`.

Quando a sua última aplicação migrar, este projeto deixa de ser necessário.

## Pedindo ou adicionando uma base

- **Pedir:** abra uma issue com o formulário *Pedir uma nova base*. Aceitamos versões
  do Node.js sem correção oficial (12 a 20) que compilem hoje.
- **Adicionar:** use `scripts/new-base.sh` e abra um pull request. O passo a passo
  está em [CONTRIBUTING.md](CONTRIBUTING.md).

A estrutura do repositório:

```
common/                    script de build, patches do Brotli e verificador
<pasta por base>/          Dockerfile da base (nome = imagem original)
.github/workflows/         um workflow por pasta + o workflow reutilizável (_build.yml)
scripts/new-base.sh        gera a pasta e o workflow de uma base nova
```

## Manutenção e suporte

Melhor esforço, **sem SLA** e sem promessa de rebuild a cada novo CVE do Node.js.
Para relatar uma vulnerabilidade neste projeto, use o relato privado do GitHub
(veja [SECURITY.md](SECURITY.md)).

## Licença e créditos

[MIT](LICENSE). Este projeto redistribui binários derivados de:

- [Node.js](https://github.com/nodejs/node), licença MIT (o texto vai em `/NODE-LICENSE`);
- [Brotli](https://github.com/google/brotli), licença MIT. Os patches em `common/` são
  derivados dos diffs oficiais do Google.

"Node.js" é marca registrada do OpenJS Foundation. Este projeto não tem
afiliação, endosso nem patrocínio dele.

## Referências

- [Registro do CVE-2026-111497 no Debian Security Tracker](https://security-tracker.debian.org/tracker/CVE-2026-111497)
- [Node.js 24.22.1 (LTS), release de segurança](https://nodejs.org/en/blog/release/v24.22.1)
- [google/brotli v1.0.10](https://github.com/google/brotli/releases/tag/v1.0.10) e [v1.1.1](https://github.com/google/brotli/releases/tag/v1.1.1)
- [Análise da Aikido sobre o Node2Shell](https://www.aikido.dev/blog/node2shell-nodejs-brotli-rce-cve-2026-111497)
- [Fim de vida do Node.js](https://nodejs.org/en/about/eol)
