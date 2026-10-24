# Contribuindo

Obrigado por ajudar. Este projeto tem um escopo estreito de propósito: **publicar
binários do Node.js em fim de vida com o decoder Brotli corrigido
(CVE-2026-111497)**, sem alterar mais nada. Contribuições que ampliem esse escopo
(outras CVEs, otimizações, mudanças de flags de build) provavelmente serão
recusadas, porque quebram a garantia de "mesmo binário, só com o Brotli
corrigido".

## Pedindo uma base nova

Abra uma issue com o formulário **"Pedir uma nova base"**. Informe a imagem base
com a **tag exata** (por exemplo `node:18.20.8-slim`, nunca `node:18-slim`).

Aceitamos pedidos para versões do Node.js **sem correção oficial** (12 a 20) e
cuja base compile hoje. Não aceitamos bases que já têm correção oficial: use a
versão corrigida do Node.js (22.23.4, 24.22.1 ou 26.12.1).

## Adicionando uma base por pull request

1. Gere a pasta e o workflow:

   ```sh
   scripts/new-base.sh <pasta> <imagem-base> <tag-publicada> <caminho-do-node> <versao>
   # exemplo
   scripts/new-base.sh node-18.20.8-slim node:18.20.8-slim 18.20.8-slim-brotli-patch /usr/local/bin/node 18.20.8
   ```

2. Confirme o caminho do `node` na imagem (`docker run --rm <base> sh -c 'command -v node'`)
   e que a versão do Node.js na base é exatamente a informada.
3. Compile localmente para ter certeza de que funciona (pode levar de 20 a 60 min):

   ```sh
   docker build -f <pasta>/Dockerfile -t teste-brotli-patch .
   ```

   O build já executa `common/verify.js` dentro da base original; se falhar, o
   problema é real.
4. Adicione a linha da base na tabela do [README](README.md).
5. Abra o pull request. O CI roda `actionlint`, `shellcheck`, `hadolint` e
   confere a sintaxe do verificador. A publicação da imagem só acontece depois do
   merge.

## Regras que não mudam

- **Mesma versão do Node.js da base.** O script lê a versão da própria base; nunca
  fixe uma versão diferente.
- **Somente o Brotli muda.** Os patches em `common/` são o diff oficial do
  google/brotli, restrito a `c/`. Não adicione outras alterações.
- **Verificação obrigatória.** Nada é publicado se `common/verify.js` falhar.
- **Sem nomes ou dados internos** de empresas nos arquivos do repositório.

## Estilo

- Shell POSIX (`sh`), validado com `shellcheck`. Sem *bashisms* em `common/`.
- Dockerfiles validados com `hadolint`.
- Mensagens de commit no formato *conventional commits* (`fix:`, `feat:`, `docs:`, `ci:`).
