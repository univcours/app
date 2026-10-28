import { env } from "cloudflare:workers";

function secret() {
  if (!env.SESSION_SECRET || env.SESSION_SECRET.length < 32) throw new Error("Configuration de sécurité indisponible.");
  return env.SESSION_SECRET;
}
const encoder = new TextEncoder();
function base64url(bytes: Uint8Array) {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
export async function digest(value: string) {
  return base64url(new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(value))));
}
export function cookieValue(request: Request, name: string) {
  return (request.headers.get("cookie") || "").split(";").map(part => part.trim()).find(part => part.startsWith(name + "="))?.slice(name.length + 1);
}
async function signature(value: string) {
  const key = await crypto.subtle.importKey("raw", encoder.encode(secret()), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return base64url(new Uint8Array(await crypto.subtle.sign("HMAC", key, encoder.encode(value))));
}
export async function equalSecret(left: string, right: string) {
  const a = await digest(left), b = await digest(right);
  let difference = 0;
  for (let index = 0; index < a.length; index++) difference |= a.charCodeAt(index) ^ b.charCodeAt(index);
  return difference === 0;
}
export async function signToken(kind: string, value: string, maxAge: number) {
  const data = base64url(encoder.encode(JSON.stringify({ kind, value, exp: Date.now() + maxAge * 1000 })));
  return `${data}.${await signature(data)}`;
}
export async function readToken(request: Request, name: string, kind: string) {
  // The GitHub Pages client uses the same signed sessions over an explicitly
  // allowed origin, without depending on third-party cookies.
  const token = trustedWebOrigin(request)
    ? /^Bearer ([A-Za-z0-9_.-]+)$/.exec(request.headers.get("authorization") || "")?.[1]
    : cookieValue(request, name);
  if (!token || token.length > 1500) return null;
  const [data, signed, extra] = token.split(".");
  if (!data || !signed || extra || !(await equalSecret(signed, await signature(data)))) return null;
  try {
    const decoded = JSON.parse(atob(data.replace(/-/g, "+").replace(/_/g, "/")));
    return decoded.kind === kind && typeof decoded.value === "string" && decoded.exp > Date.now() ? decoded.value as string : null;
  } catch { return null; }
}
export function cookieHeader(request: Request, name: string, value: string, maxAge: number) {
  const secure = new URL(request.url).protocol === "https:" ? "; Secure" : "";
  return `${name}=${value}; HttpOnly; SameSite=Strict; Path=/; Max-Age=${maxAge}${secure}`;
}
export function sameOrigin(request: Request) {
  const origin = request.headers.get("origin");
  if (!origin) return false;
  const target = new URL(request.url);
  // Preview and hosted dispatch both preserve the browser's host.
  return origin === target.origin;
}
export function trustedWebOrigin(request: Request) {
  const origin = request.headers.get("origin");
  return !!env.PUBLIC_WEB_ORIGIN && origin === env.PUBLIC_WEB_ORIGIN;
}
