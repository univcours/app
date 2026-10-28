"use client";

import { useEffect, useState } from "react";
import { ArrowLeft, ArrowRight, Building2, Check, ChevronDown, ClipboardList, Download, FileSpreadsheet, Link2, LoaderCircle, LockKeyhole, LogOut, RefreshCw, Search, ShieldCheck, Trash2, X } from "lucide-react";
import catalog from "../../lib/catalog.json";
import { Footer, Header, formatDate } from "../components";
import DeleteDialog from "./delete-dialog";

type Submission = { id: string; agency: string; items: { id: string; quantity: number; comment: string }[]; createdAt: string; updatedAt: string };

export default function AdminApp() {
  const [authenticated, setAuthenticated] = useState(false);
  const [loading, setLoading] = useState(true);
  const [password, setPassword] = useState("");
  const [responses, setResponses] = useState<Submission[]>([]);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [filter, setFilter] = useState("");
  const [exportAgency, setExportAgency] = useState("");
  const [opened, setOpened] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Submission | null>(null);
  const [feedback, setFeedback] = useState("");

  async function load() {
    setLoading(true); setError("");
    try {
      const response = await fetch("/api/admin/responses", { cache: "no-store" });
      if (response.status === 401) { setAuthenticated(false); return; }
      const data = await response.json() as { error?: string; responses: Submission[] };
      if (!response.ok) throw new Error(data.error);
      setResponses(data.responses); setAuthenticated(true);
    } catch (problem) { setError(problem instanceof Error ? problem.message : "Chargement impossible."); }
    finally { setLoading(false); }
  }
  useEffect(() => { void load(); }, []);
  async function login(event: React.FormEvent) {
    event.preventDefault(); setBusy(true); setError("");
    try {
      const response = await fetch("/api/admin/login", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ password }) });
      const data = await response.json() as { error?: string };
      if (!response.ok) throw new Error(data.error);
      setPassword(""); await load();
    } catch (problem) { setError(problem instanceof Error ? problem.message : "Connexion impossible."); }
    finally { setBusy(false); }
  }
  async function download() {
    setBusy(true); setError("");
    try {
      const response = await fetch(`/api/admin/export${exportAgency ? '?agency=' + encodeURIComponent(exportAgency) : ''}`, { cache: "no-store" });
      if (!response.ok) { const data = await response.json() as { error?: string }; if (response.status === 401) setAuthenticated(false); throw new Error(data.error); }
      const blob = await response.blob(), url = URL.createObjectURL(blob), link = document.createElement("a");
      link.href = url; link.download = /filename="([^"]+)"/.exec(response.headers.get("content-disposition") || "")?.[1] || "Besoins_2027.xlsx";
      document.body.appendChild(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch (problem) { setError(problem instanceof Error ? problem.message : "Téléchargement impossible."); }
    finally { setBusy(false); }
  }
  async function copyLink() { try { await navigator.clipboard.writeText(window.location.origin + "/"); setCopied(true); setTimeout(() => setCopied(false), 2000); } catch { setError("Le lien du formulaire est l’adresse du site sans /gestion."); } }
  async function removeAgency() {
    if (!deleteTarget || busy) return;
    setBusy(true); setError(""); setFeedback("");
    try {
      const response = await fetch("/api/admin/delete", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id: deleteTarget.id, updatedAt: deleteTarget.updatedAt }) });
      const data = await response.json() as { error?: string; id: string; agency: string };
      if (!response.ok) { if (response.status === 401) setAuthenticated(false); throw new Error(data.error || "La suppression a échoué."); }
      setResponses(previous => previous.filter(row => row.id !== data.id));
      if (exportAgency === data.id) setExportAgency("");
      if (opened === data.id) setOpened(null);
      setFeedback(`La demande de « ${data.agency} » a été supprimée. Elle ne figure plus dans les exports Excel.`);
    } catch (problem) { setError(problem instanceof Error ? problem.message : "La suppression a échoué. Actualisez la liste."); }
    finally { setBusy(false); setDeleteTarget(null); }
  }

  const visible = responses.filter(response => response.agency.toLowerCase().includes(filter.toLowerCase()));
  const latest = responses.reduce((date, response) => response.updatedAt > date ? response.updatedAt : date, "");
  return <><Header admin/><main className="admin-main">{!authenticated ? <section className="admin-login"><a className="back-link" href="/"><ArrowLeft size={15}/>Retour au formulaire</a><span className="soft-icon"><LockKeyhole size={26}/></span><span className="eyebrow muted">ACCÈS RÉSERVÉ</span><h1>Espace coordinateur</h1><p>Consultez les demandes des agences et téléchargez le fichier Excel consolidé.</p><form onSubmit={login}><label htmlFor="admin-password">Mot de passe</label><input id="admin-password" type="password" autoComplete="current-password" required maxLength={200} placeholder="Votre mot de passe coordinateur" value={password} onChange={event => setPassword(event.target.value)}/>{error && <div className="error-message" role="alert">{error}</div>}<button type="submit" className="button primary full" disabled={busy || loading}>{busy || loading ? <LoaderCircle className="spin" size={18}/> : <>Ouvrir l’espace coordinateur<ArrowRight size={17}/></>}</button></form><span className="login-footnote"><ShieldCheck size={15}/>Les demandes et l’export sont protégés.</span></section> : <>
    <div className="workspace-title"><div><span className="eyebrow muted">DR CASABLANCA-SETTAT · BUDGET 2027</span><h1>Les besoins, réunis.</h1><p>Toutes les demandes des agences dans votre modèle Excel d’origine.</p></div><div className="admin-header-actions"><button className="button secondary" onClick={() => void copyLink()}>{copied ? <Check size={16}/> : <Link2 size={16}/>} {copied ? "Lien copié" : "Lien du formulaire"}</button><button aria-label="Se déconnecter" title="Se déconnecter" className="icon-button" onClick={async () => { await fetch("/api/admin/logout", { method: "POST" }); setAuthenticated(false); setResponses([]); }}><LogOut size={19}/></button></div></div>
    <div className="admin-stats"><div><span className="soft-icon small"><Building2 size={20}/></span><span><strong>{responses.length}</strong><small>Agences participantes</small></span></div><div><span className="soft-icon small"><ClipboardList size={20}/></span><span><strong>{responses.reduce((sum, response) => sum + response.items.length, 0)}</strong><small>Lignes de besoins reçues</small></span></div><div><span className="soft-icon small"><FileSpreadsheet size={20}/></span><span><strong>2 feuilles</strong><small>Modèle Excel conservé</small></span></div></div>
    <section className="export-card"><div><span className="eyebrow">EXPORT EXCEL</span><h2>Votre fichier, prêt à télécharger.</h2><p>Les quantités sont additionnées par équipement. Chaque commentaire détaille l’agence, la quantité et les précisions transmises.</p></div><div className="export-controls"><label htmlFor="export-agency">Périmètre de l’export</label><select id="export-agency" value={exportAgency} onChange={event => setExportAgency(event.target.value)}><option value="">Toutes les agences · consolidé</option>{responses.map(response => <option key={response.id} value={response.id}>{response.agency}</option>)}</select><button className="button export-button" disabled={busy || !responses.length} onClick={() => void download()}>{busy ? <LoaderCircle className="spin" size={18}/> : <Download size={18}/>}Télécharger le fichier Excel</button></div></section>
    {error && <div className="error-message" role="alert">{error}</div>}
    {feedback && <div className="notice delete-feedback" role="status"><Check size={17}/><span>{feedback}</span><button aria-label="Fermer le message" className="text-button" onClick={() => setFeedback("")}><X size={15}/></button></div>}
    <section className="responses-panel"><div className="responses-toolbar"><div><h2>Demandes des agences <span>{responses.length}</span></h2><p>{latest ? `Dernière réception : ${formatDate(latest)}` : "Les demandes apparaîtront ici après leur envoi."}</p></div><div className="responses-actions"><div className="search-field"><Search size={17}/><input aria-label="Rechercher une agence" placeholder="Rechercher une agence…" value={filter} onChange={event => setFilter(event.target.value)}/>{filter && <button aria-label="Effacer la recherche" onClick={() => setFilter("")}><X size={15}/></button>}</div><button className="icon-button" disabled={loading} title="Actualiser les demandes" aria-label="Actualiser les demandes" onClick={() => void load()}><RefreshCw size={18} className={loading ? "spin" : ""}/></button></div></div>
    {!visible.length ? <div className="empty-state"><ClipboardList size={30}/><strong>{filter ? "Aucune agence correspondante" : "La collecte peut commencer."}</strong><p>{filter ? "Essayez un autre nom d’agence." : "Partagez le lien du formulaire avec vos agences pour recevoir leurs besoins."}</p></div> : <div className="response-list">{visible.map(response => <article key={response.id} className="response-card"><div className="response-heading"><button className="response-summary" aria-expanded={opened === response.id} onClick={() => setOpened(opened === response.id ? null : response.id)}><span className="agency-initial">{response.agency.charAt(0).toUpperCase()}</span><span><strong>{response.agency}</strong><small>{formatDate(response.updatedAt)}</small></span><b>{response.items.length} article{response.items.length > 1 ? "s" : ""}</b><ChevronDown size={17} className={opened === response.id ? "rotated" : ""}/></button><button className="delete-agency-button" disabled={busy} aria-label={`Supprimer la demande de ${response.agency}`} title={`Supprimer la demande de ${response.agency}`} onClick={() => { setDeleteTarget(response); setError(""); setFeedback(""); }}><Trash2 size={16}/><span>Supprimer</span></button></div>{opened === response.id && <div className="response-detail"><table><thead><tr><th>Équipement</th><th>Quantité</th><th>Commentaire et autres précisions</th></tr></thead><tbody>{response.items.map(item => <tr key={item.id}><td>{catalog.items.find(equipment => equipment.id === item.id)?.label || item.id}</td><td>{new Intl.NumberFormat("fr-FR").format(item.quantity)}</td><td>{item.comment || "—"}</td></tr>)}</tbody></table></div>}</article>)}</div>}</section>
  </>}</main><Footer/>{authenticated && deleteTarget && <DeleteDialog agency={deleteTarget.agency} itemCount={deleteTarget.items.length} busy={busy} cancel={() => { if (!busy) setDeleteTarget(null); }} confirm={() => void removeAgency()}/>}</>;
}
