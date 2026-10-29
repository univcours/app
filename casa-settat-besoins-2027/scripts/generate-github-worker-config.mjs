import { writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';

const id = process.env.UNIVCOURS_D1_DATABASE_ID?.trim();
const workerName = (process.env.UNIVCOURS_WORKER_NAME || 'univcours-comptage-api').trim();
if (!/^[0-9a-f]{8}-[0-9a-f-]{27,36}$/i.test(id || '')) {
  throw new Error('Set GitHub Actions variable UNIVCOURS_D1_DATABASE_ID with the actual Cloudflare D1 UUID.');
}
if (!/^[a-z0-9-]{3,63}$/.test(workerName)) throw new Error('Invalid worker name.');

const config = {
  name: workerName,
  main: './standalone-api.ts',
  compatibility_date: '2026-10-01',
  compatibility_flags: ['nodejs_compat'],
  workers_dev: true,
  d1_databases: [{
    binding: 'DB',
    database_name: 'univcours-comptage',
    database_id: id,
    migrations_dir: './migrations',
  }],
  vars: { PUBLIC_WEB_ORIGIN: 'https://univcours.github.io' },
};
const dest = path.resolve('worker/wrangler.generated.json');
await mkdir(path.dirname(dest), { recursive: true });
await writeFile(dest, JSON.stringify(config, null, 2) + '\n');
console.log('Generated Cloudflare Worker deployment config for '+workerName+' (API URL only; no secrets written).');
