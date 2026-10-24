'use strict';
// Verificação executada DENTRO da imagem base original, com o binário corrigido já
// no lugar. Se qualquer checagem falhar, o build falha e nada é publicado.
const assert = require('assert');
const crypto = require('crypto');
const zlib = require('zlib');

const FIXED_BROTLI = new Set(['1.0.10', '1.1.1']);
assert(FIXED_BROTLI.has(process.versions.brotli),
  `Brotli ${process.versions.brotli} não é uma versão corrigida (${[...FIXED_BROTLI].join(', ')})`);

// 1) Roundtrip de compressão/descompressão com dados variados, vários níveis.
for (const size of [0, 1, 100, 65536, 1 << 20]) {
  for (const quality of [0, 1, 5, 9, 11]) {
    const chunk = crypto.randomBytes(Math.min(size, 4096) || 1);
    const data = Buffer.concat(Array(Math.ceil(size / chunk.length) || 1).fill(chunk)).subarray(0, size);
    const encoded = zlib.brotliCompressSync(data, { params: { [zlib.constants.BROTLI_PARAM_QUALITY]: quality } });
    assert(zlib.brotliDecompressSync(encoded).equals(data), `roundtrip falhou (size=${size}, q=${quality})`);
  }
}

// 2) Caso de regressão do próprio Node.js para o CVE: troca de bloco inválida
//    (um stream que declara um só tipo de bloco) deve ser rejeitada.
const invalidBlockSwitch = Buffer.from('200010414141fcffff07002228f00b60f7f41f000000', 'hex');
// O nome do erro está em err.code (ERR_BLOCK_SWITCH no Node 14, ERR__ERROR_FORMAT_BLOCK_SWITCH
// no Node 20); a mensagem é só "Decompression failed".
assert.throws(() => zlib.brotliDecompressSync(invalidBlockSwitch),
  (err) => /BLOCK_SWITCH/.test(String(err.code)),
  'o stream com troca de bloco inválida deveria ser rejeitado com código BLOCK_SWITCH');

// 3) Os demais módulos que dependem de zlib continuam funcionando.
const text = Buffer.from('brotli-patch '.repeat(1000));
assert(zlib.gunzipSync(zlib.gzipSync(text)).equals(text));
assert(zlib.inflateSync(zlib.deflateSync(text)).equals(text));

console.log(`ok: node ${process.version}, brotli ${process.versions.brotli}`);
