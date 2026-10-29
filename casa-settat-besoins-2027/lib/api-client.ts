declare const __BUDGET_API_BASE__: string | undefined;
declare const __BUDGET_FORM_PATH__: string | undefined;

const apiBase = typeof __BUDGET_API_BASE__ === "string" ? __BUDGET_API_BASE__ : "";
export const formPath = typeof __BUDGET_FORM_PATH__ === "string" ? __BUDGET_FORM_PATH__ : "/";
export const managementPath = apiBase ? `${formPath}?page=gestion` : "/gestion";
export const countingPath = apiBase ? `${formPath}?page=comptage` : "/comptage";
export const countingManagementPath = apiBase ? `${formPath}?page=gestion-comptage` : "/gestion?section=comptage";
const participantKey = "besoin2027-participant-session";
const adminKey = "besoin2027-coordinateur-session";
let participantToken = "", adminToken = "";

function tokenFor(admin: boolean) {
  try { return (admin ? sessionStorage.getItem(adminKey) : localStorage.getItem(participantKey)) || (admin ? adminToken : participantToken); }
  catch { return admin ? adminToken : participantToken; }
}
function saveToken(admin: boolean, token: string) {
  if (admin) adminToken = token; else participantToken = token;
  try { (admin ? sessionStorage : localStorage).setItem(admin ? adminKey : participantKey, token); } catch {}
}
function clearAdmin() {
  adminToken = "";
  try { sessionStorage.removeItem(adminKey); } catch {}
}

export async function apiFetch(path: string, options: RequestInit = {}) {
  if (!apiBase) return fetch(path, options);
  const isAdmin = path.startsWith("/api/admin/");
  const token = tokenFor(isAdmin);
  const headers = new Headers(options.headers);
  if (token) headers.set("Authorization", `Bearer ${token}`);
  let response: Response;
  try {
    response = await fetch(apiBase + path, { ...options, headers, mode: "cors", credentials: "omit" });
  } finally { if (path === "/api/admin/logout") clearAdmin(); }
  if (isAdmin && response.status === 401) clearAdmin();
  if (response.ok && ["/api/session", "/api/comptage/session", "/api/admin/login"].includes(path.split('?')[0])) {
    const data = await response.clone().json() as { participantToken?: string; adminToken?: string };
    if (typeof data.participantToken === "string") saveToken(false, data.participantToken);
    if (typeof data.adminToken === "string") saveToken(true, data.adminToken);
  }
  return response;
}
