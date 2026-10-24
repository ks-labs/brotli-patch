# Política de segurança

## Escopo

Este repositório publica **binários do Node.js recompilados** com a correção do
decoder Brotli (CVE-2026-111497). Ele **não** é uma distribuição oficial do
Node.js e **não** corrige nenhuma outra vulnerabilidade das linhas de Node.js em
fim de vida.

Dentro do escopo:

- falhas no processo de build ou na cadeia de suprimentos deste repositório
  (workflows, scripts, patches, imagens publicadas);
- um binário publicado cuja versão do Node.js ou do Brotli **não** corresponde ao
  que a tag promete;
- regressão de comportamento introduzida pelo patch em relação ao binário oficial
  da mesma versão.

Fora do escopo:

- vulnerabilidades do próprio Node.js, do OpenSSL, do V8 ou de outras
  dependências em versões sem suporte. Elas não são corrigidas aqui; migre para
  uma versão suportada do Node.js;
- vulnerabilidades do sistema operacional da sua imagem base.

## Como reportar

Use o **relato privado de vulnerabilidades do GitHub**: aba *Security* do
repositório → *Report a vulnerability*. Não abra issue pública para um problema
que possa ser explorado.

Informe a tag da imagem, o digest (`docker buildx imagetools inspect <imagem>`),
os passos para reproduzir e o impacto observado.

## Prazos

O projeto é mantido em regime de **melhor esforço, sem SLA**. Relatos são lidos e
respondidos sempre que possível, sem prazo garantido de resposta ou correção.

## Verificando o que você baixou

Cada imagem publicada traz atestados de proveniência e SBOM gerados pelo BuildKit
e o arquivo `/build-info.json` com as versões e os hashes do build. Veja a seção
"Verificação" do [README](README.md).
