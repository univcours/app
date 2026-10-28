import fs from 'node:fs/promises';
import path from 'node:path';
import { build } from 'vite';

const root = path.resolve(import.meta.dirname, '..');
const output = path.join(root, 'outputs/github-pages');
await build({
  configFile: false,
  root: path.join(root, 'github-pages'),
  base: '/app/besoin2027/',
  publicDir: path.join(root, 'public'),
  css: { postcss: root },
  define: {
    __BUDGET_API_BASE__: JSON.stringify('https://besoin2027.hamidtawfiq2.chatgpt.site'),
    __BUDGET_FORM_PATH__: JSON.stringify('/app/besoin2027/'),
  },
  build: { outDir: path.join(output, 'besoin2027'), emptyOutDir: true, sourcemap: false },
});
await fs.writeFile(path.join(output, '.nojekyll'), '\n');
await fs.writeFile(path.join(output, 'index.html'), '<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="refresh" content="0;url=./besoin2027/"><title>Besoin2027</title></head><body><a href="./besoin2027/">Ouvrir Besoin2027</a></body></html>');
console.log(`GitHub Pages files: ${output}`);
