const base = String(process.env.UNIVCOURS_API_URL || '').replace(/\/+$/, '');
if (!/^https:\/\/[a-z0-9.-]+(?::\d+)?$/i.test(base)) {
  throw new Error('Set GitHub Actions variable UNIVCOURS_API_URL to the HTTPS base URL of the published Worker.');
}
const url = base + '/api/controle/health';
const timeout = AbortSignal.timeout(15000);
const response = await fetch(url, { signal: timeout, cache: 'no-store' });
const result = await response.json().catch(() => null);
if (!response.ok || result?.ready !== true) {
  throw new Error('Barcode service is not ready: status=' + response.status + ', response=' + JSON.stringify(result).slice(0,150));
}
console.log('Barcode API is healthy and all three D1 tables are available:', url);
