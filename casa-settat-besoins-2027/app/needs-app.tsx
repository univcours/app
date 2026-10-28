"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { AlertTriangle, ArrowLeft, ArrowRight, Check, CheckCircle2, ChevronRight, ClipboardList, Clock3, FileCheck2, Info, Laptop, LoaderCircle, MapPin, Package, Search, Send, ShieldCheck, X } from "lucide-react";
import catalog from "../lib/catalog.json";
import { Footer, Header, formatDate } from "./components";
import { draftSnapshot, submittedSnapshot, UNSENT_AR, UNSENT_FR } from "../lib/form-state.mjs";
import { useUnsentWarning } from "./use-unsent-warning";
import ExitWarning from "./exit-warning";
import { apiFetch } from "../lib/api-client";

type Value = { quantity: string; comment: string };
type Values = Record<string, Value>;
type Receipt = { id: string; updatedAt: string };
type SessionResponse = { error?: string; submission?: { id: string; agency: string; updatedAt: string; items: { id: string; quantity: number; comment: string }[] } };
const STORAGE = "casa-settat-besoins-2027-v1";
const normalized = (value: string) => value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
const quantity = (value: string) => Number(value.replace(",", "."));

export default function NeedsApp() {
  const [agency, setAgency] = useState("");
  const [started, setStarted] = useState(false);
  const [values, setValues] = useState<Values>({});
  const [sheet, setSheet] = useState(1);
  const [category, setCategory] = useState("");
  const [search, setSearch] = useState("");
  const [onlySelected, setOnlySelected] = useState(false);
  const [ready, setReady] = useState(false);
  const [booted, setBooted] = useState(false);
  const [error, setError] = useState("");
  const [sessionError, setSessionError] = useState("");
  const [review, setReview] = useState(false);
  const [busy, setBusy] = useState(false);
  const [receipt, setReceipt] = useState<Receipt | null>(null);
  const [sentSnapshot, setSentSnapshot] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [savedLocally, setSavedLocally] = useState(false);
  const reviewRef = useRef<HTMLButtonElement>(null);
  const hadDraft = useRef(false);
  const currentAgency = useRef(agency);
  currentAgency.current = agency;
  const snapshot = useMemo(() => draftSnapshot(agency, values, catalog.items), [agency, values]);
  const hasDraft = !!agency.trim() || Object.values(values).some(value => value.quantity || value.comment.trim());
  const hasUnsentChanges = booted && hasDraft && !success && snapshot !== sentSnapshot;
  const { exitHref, cancelExit, confirmExit } = useUnsentWarning(hasUnsentChanges);

  async function initialize(restore = true) {
    setSessionError("");
    try {
      const response = await apiFetch("/api/session", { cache: "no-store" });
      const data = await response.json() as SessionResponse;
      if (!response.ok) throw new Error(data.error);
      setReady(true);
      if (data.submission) {
        setSentSnapshot(submittedSnapshot(data.submission.agency, data.submission.items, catalog.items));
        if (!hadDraft.current || normalized(currentAgency.current.trim()) === normalized(data.submission.agency)) {
          setReceipt({ id: data.submission.id, updatedAt: data.submission.updatedAt });
        }
      } else { setSentSnapshot(null); setReceipt(null); }
      if (restore && !hadDraft.current && data.submission) {
        setAgency(data.submission.agency);
        setValues(Object.fromEntries(data.submission.items.map((item: { id: string; quantity: number; comment: string }) => [item.id, { quantity: String(item.quantity), comment: item.comment }])));
        setReceipt({ id: data.submission.id, updatedAt: data.submission.updatedAt });
        setStarted(true);
      }
    } catch (problem) { setReady(false); setSessionError(problem instanceof Error ? problem.message : "Connexion indisponible. Réessayez avant d’envoyer."); }
  }

  useEffect(() => {
    try {
      const draft = JSON.parse(localStorage.getItem(STORAGE) || "null");
      if (draft && typeof draft.agency === "string" && draft.values && typeof draft.values === "object") {
        hadDraft.current = true;
        setAgency(draft.agency); setValues(draft.values); setStarted(!!draft.started); setReceipt(draft.receipt || null);
        setSentSnapshot(typeof draft.sentSnapshot === "string" ? draft.sentSnapshot : null);
        if (draft.sheet === 1 || draft.sheet === 2) setSheet(draft.sheet);
      }
    } catch {}
    setBooted(true);
    void initialize();
  }, []);

  useEffect(() => {
    if (!booted) return;
    try { localStorage.setItem(STORAGE, JSON.stringify({ agency, values, started, receipt, sentSnapshot, sheet })); setSavedLocally(true); } catch { setSavedLocally(false); }
  }, [agency, values, started, receipt, sentSnapshot, sheet, booted]);

  useEffect(() => {
    if (!review) return;
    reviewRef.current?.focus();
    const handler = (event: KeyboardEvent) => {
      if (event.key === "Escape" && !busy) setReview(false);
      if (event.key === "Tab") {
        const dialog = document.querySelector('.review-dialog');
        const elements = Array.from(dialog?.querySelectorAll<HTMLButtonElement>('button:not(:disabled), a[href], input, select, textarea') || []);
        const first = elements[0], last = elements[elements.length - 1];
        if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
        if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
      }
    };
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", handler);
    return () => { document.body.style.overflow = previous; window.removeEventListener("keydown", handler); };
  }, [review, busy]);

  const selected = useMemo(() => catalog.items.filter(item => quantity(values[item.id]?.quantity || "") > 0), [values]);
  const categories = [...new Set(catalog.items.filter(item => item.sheet === sheet).map(item => item.category))];
  const visible = catalog.items.filter(item => item.sheet === sheet && (!category || item.category === category) && (!onlySelected || quantity(values[item.id]?.quantity || "") > 0) && (!search || normalized(item.label + " " + item.category).includes(normalized(search))));
  const currentSheet = catalog.sheets.find(item => item.id === sheet)!;

  function change(id: string, field: keyof Value, value: string) {
    setValues(previous => ({ ...previous, [id]: { quantity: previous[id]?.quantity || "", comment: previous[id]?.comment || "", [field]: value } }));
    setError("");
  }
  function validate(onlySheet?: number) {
    for (const item of catalog.items.filter(item => onlySheet === undefined || item.sheet === onlySheet)) {
      const value = values[item.id];
      if (!value) continue;
      const number = quantity(value.quantity);
      if ((value.comment.trim() && !value.quantity) || (value.quantity && (!Number.isFinite(number) || number <= 0 || number > 100000 || Math.abs(number * 100 - Math.round(number * 100)) > 0.00001))) {
        setError(`Vérifiez la quantité de « ${item.label} » : valeur positive, deux décimales au maximum.`);
        setSheet(item.sheet); setCategory(""); setSearch(""); setOnlySelected(false);
        setTimeout(() => document.getElementById(`qty-${item.id}`)?.focus(), 50);
        return false;
      }
    }
    if (onlySheet === undefined && !selected.length) { setError("Renseignez la quantité d’au moins un équipement avant d’envoyer."); return false; }
    setError(""); return true;
  }
  async function submit() {
    if (!validate()) { setReview(false); return; }
    setBusy(true); setError("");
    try {
      const response = await apiFetch("/api/submit", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ agency, items: selected.map(item => ({ id: item.id, quantity: quantity(values[item.id].quantity), comment: values[item.id].comment })) }) });
      const result = await response.json() as { error?: string; id: string; updatedAt: string };
      if (!response.ok) throw new Error(result.error || "L’envoi a échoué. Réessayez.");
      setSentSnapshot(snapshot); setReceipt({ id: result.id, updatedAt: result.updatedAt }); setReview(false); setSuccess(true); window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (problem) { setError(problem instanceof Error ? problem.message : "L’envoi a échoué. Vos saisies sont conservées."); }
    finally { setBusy(false); }
  }
  function selectSheet(id: number) { setSheet(id); setCategory(""); setSearch(""); setOnlySelected(false); }
  function continueToNextSheet() {
    if (!validate(sheet)) return;
    selectSheet(2);
    requestAnimationFrame(() => { document.getElementById("sheet-title")?.focus({ preventScroll: true }); document.querySelector(".sheet-tabs")?.scrollIntoView({ behavior: "smooth", block: "start" }); });
  }

  return <><Header/><main className={!started ? "welcome-main" : "workspace-main"}>
    {!started ? <section className="welcome-grid">
      <div className="welcome-story"><span className="eyebrow"><span className="status-dot"/> CAMPAGNE BUDGÉTAIRE 2027</span><h1>Les bons équipements.<br/><em>Pour chaque agence.</em></h1><p>Faites remonter vos besoins en matériel pour préparer le prochain budget d’investissement de la DR Casablanca-Settat.</p><div className="welcome-facts"><span><Laptop size={19}/><strong>12</strong> articles informatiques</span><span><Package size={19}/><strong>163</strong> autres équipements</span></div><div className="welcome-steps"><div><b>01</b><span>Identifiez votre agence</span></div><div><b>02</b><span>Renseignez vos quantités</span></div><div><b>03</b><span>Vérifiez et envoyez</span></div></div><span className="story-footnote"><ClipboardList size={15}/> Deux feuilles, un seul formulaire.</span></div>
      <div className="welcome-form-card"><span className="soft-icon"><MapPin size={25}/></span><span className="eyebrow muted">POUR COMMENCER</span><h2>Quelle est votre agence ?</h2><p>Son nom sera associé à chaque quantité demandée dans le fichier final.</p><form onSubmit={event => { event.preventDefault(); if (agency.trim().length < 2) { setError("Indiquez le nom complet de votre agence."); return; } setAgency(agency.replace(/\s+/g, " ").trim()); setStarted(true); setError(""); }}><label htmlFor="agency">Nom de l’agence <span className="required">*</span></label><input id="agency" autoComplete="organization" required minLength={2} maxLength={100} value={agency} onChange={event => setAgency(event.target.value)} placeholder="Ex. : Agence Settat"/><span className="field-help">DR Casablanca-Settat · Nom complet de l’agence</span>{error && <div className="error-message" role="alert">{error}</div>}<button className="button primary full" type="submit">Accéder au formulaire <ArrowRight size={18}/></button></form><div className="privacy-note"><ShieldCheck size={19}/><span>Vous renseignez uniquement les quantités et les précisions utiles à votre demande.</span></div></div>
    </section> : success && receipt ? <section className="success-card"><span className="success-icon"><CheckCircle2 size={37}/></span><span className="eyebrow muted">DEMANDE ENREGISTRÉE</span><h1>Merci, vos besoins<br/>ont bien été transmis.</h1><p>Les besoins de <strong>{agency}</strong> sont disponibles pour la consolidation du budget 2027.</p><div className="receipt-summary"><span><ClipboardList size={18}/> {selected.length} article{selected.length > 1 ? "s" : ""} renseigné{selected.length > 1 ? "s" : ""}</span><span><Clock3 size={18}/>{formatDate(receipt.updatedAt)}</span></div><div className="success-next"><Info size={18}/><p>Vous pouvez actualiser votre demande depuis ce navigateur. Votre nouvelle saisie remplacera la précédente pour cette agence.</p></div><button className="button primary" onClick={() => setSuccess(false)}>Modifier mes besoins <ArrowRight size={17}/></button></section> : <>
      <div className="workspace-title"><div><span className="eyebrow muted">EXPRESSION DES BESOINS · INVESTISSEMENT</span><h1>Votre agence, vos besoins.</h1><p>Indiquez les quantités souhaitées et ajoutez vos précisions.</p></div><div className="agency-badge"><span className="soft-icon small"><MapPin size={18}/></span><div><small>VOTRE AGENCE</small><strong>{agency}</strong></div>{!receipt && <button className="text-button" onClick={() => setStarted(false)}>Modifier</button>}</div></div>
      {receipt && <div className="notice"><FileCheck2 size={18}/><span>Dernier envoi : {formatDate(receipt.updatedAt)}. Un nouvel envoi remplacera votre demande précédente.</span></div>}
      {hasUnsentChanges && <div className="unsent-notice" role="status"><AlertTriangle size={19}/><div><strong>Demande non envoyée <span lang="ar" dir="rtl">الطلب غير مُرسَل</span></strong><p lang="fr">{UNSENT_FR}</p><p lang="ar" dir="rtl">{UNSENT_AR}</p></div></div>}
      {sessionError && <div className="error-message connection-error" role="alert"><span>{sessionError}</span><button onClick={() => void initialize(false)}>Réessayer</button></div>}
      <div className="sheet-tabs" role="tablist" aria-label="Feuilles du budget">{catalog.sheets.map(item => <button key={item.id} role="tab" aria-selected={sheet === item.id} className={sheet === item.id ? "active" : ""} onClick={() => selectSheet(item.id)}><span className="tab-step">{item.id}</span>{item.id === 1 ? <Laptop size={19}/> : <Package size={19}/>}<span>{item.title}</span><b>{item.count} articles</b><span className="sheet-selected-count">{selected.filter(selectedItem => selectedItem.sheet === item.id).length > 0 && <Check size={14}/>}</span></button>)}</div>
      <div className="sheet-step-header"><span className="step-number">0{sheet}<small>/ 02</small></span><div><h2 id="sheet-title" tabIndex={-1}>{currentSheet.title}</h2><p>{sheet === 1 ? "Complétez cette feuille, puis cliquez sur Suivant pour passer aux équipements et au mobilier." : "Complétez cette feuille, puis vérifiez votre demande avant de confirmer l’envoi."} Vous pouvez revenir à tout moment.</p></div></div>
      <div className="catalog-layout"><aside className="category-panel"><span className="eyebrow muted">RUBRIQUES</span><button className={!category ? "active" : ""} onClick={() => setCategory("")}><span>Tous les équipements</span><b>{currentSheet.count}</b></button>{categories.map(name => <button key={name} className={category === name ? "active" : ""} onClick={() => setCategory(name)}><span>{name}</span><ChevronRight size={13}/></button>)}<div className="sidebar-tip"><Info size={19}/><strong>Seulement ce qu’il vous faut.</strong><p>Laissez vides les équipements dont votre agence n’a pas besoin.</p></div></aside>
      <section className="equipment-panel" aria-label={currentSheet.title}><div className="table-toolbar"><div className="search-field"><Search size={18}/><input aria-label="Rechercher un équipement" placeholder="Rechercher un équipement…" value={search} onChange={event => setSearch(event.target.value)}/>{search && <button aria-label="Effacer la recherche" onClick={() => setSearch("")}><X size={16}/></button>}</div><button className={`selection-toggle ${onlySelected ? "active" : ""}`} aria-pressed={onlySelected} onClick={() => setOnlySelected(!onlySelected)}><ClipboardList size={16}/>Mes besoins <b>{selected.length}</b></button></div><div className="table-caption"><span>{category || currentSheet.subtitle}</span><span>{visible.length} article{visible.length > 1 ? "s" : ""}</span></div>
      <div className="table-scroll"><table className="needs-table"><thead><tr><th>Équipement</th><th className="quantity-column">Quantité <span className="required">*</span></th><th>Commentaire et autres précisions</th></tr></thead><tbody>{visible.map(item => { const value = values[item.id] || { quantity: "", comment: "" }; const active = quantity(value.quantity) > 0; return <tr key={item.id} className={active ? "selected-row" : ""}><td><span className="equipment-name">{active && <Check size={13}/>} {item.label}</span><span className="equipment-category">{item.category}</span></td><td className="quantity-cell"><input id={`qty-${item.id}`} aria-label={`Quantité : ${item.label}, ligne ${item.row}`} type="number" inputMode="decimal" min="0.01" max="100000" step="0.01" placeholder="—" value={value.quantity} onChange={event => change(item.id, "quantity", event.target.value)}/></td><td className="comment-cell"><textarea aria-label={`Commentaire : ${item.label}, ligne ${item.row}`} maxLength={1500} rows={1} placeholder="Motif, remplacement, caractéristiques…" value={value.comment} onChange={event => change(item.id, "comment", event.target.value)}/></td></tr>; })}</tbody></table>{!visible.length && <div className="empty-state"><Search size={27}/><strong>Aucun équipement affiché</strong><p>{onlySelected ? "Aucun besoin sélectionné dans cette rubrique." : "Essayez un autre mot-clé ou une autre rubrique."}</p><button className="text-button" onClick={() => { setSearch(""); setCategory(""); setOnlySelected(false); }}>Afficher tous les équipements</button></div>}</div><div className="table-footnote"><Info size={15}/><span>* Quantité obligatoire pour chaque équipement demandé. Les commentaires sont facultatifs.</span></div></section></div>
      {error && !review && <div className="error-message" role="alert">{error}</div>}
      <div className="submit-bar step-submit-bar"><div><strong><span className="count-disc">{selected.length}</span> article{selected.length > 1 ? "s" : ""} dans votre demande</strong><span className="local-save"><Check size={13}/>{hasUnsentChanges ? (savedLocally ? "Brouillon sur cet appareil · non envoyé" : "Gardez cette page ouverte jusqu’à l’envoi") : "Dernière version envoyée"}</span></div><div className="step-navigation">{sheet === 2 && <button className="button secondary" onClick={() => selectSheet(1)}><ArrowLeft size={16}/>Précédent</button>}{sheet === 1 ? <button className="button primary next-sheet-button" onClick={continueToNextSheet}><span>Suivant<small>Équipements & mobilier</small></span><ArrowRight size={18}/></button> : <button className="button primary" onClick={() => { if (validate()) setReview(true); }}>Vérifier et envoyer <ArrowRight size={18}/></button>}</div></div>
    </>}
  </main><Footer/>
  {exitHref && <ExitWarning cancel={cancelExit} leave={confirmExit}/>}
  {review && <div className="modal-backdrop" onClick={event => { if (event.target === event.currentTarget && !busy) setReview(false); }}><section className="review-dialog" role="dialog" aria-modal="true" aria-labelledby="review-title"><div className="dialog-header"><div><span className="eyebrow muted">AVANT L’ENVOI</span><h2 id="review-title">Vérifier votre demande</h2><p><MapPin size={15}/>{agency} · {selected.length} article{selected.length > 1 ? "s" : ""}</p></div><button ref={reviewRef} className="icon-button" aria-label="Fermer la vérification" disabled={busy} onClick={() => setReview(false)}><X size={20}/></button></div><div className="review-list">{selected.map(item => <div className="review-item" key={item.id}><div><strong>{item.label}</strong><span>{catalog.sheets.find(sheet => sheet.id === item.sheet)?.title}</span>{values[item.id].comment && <p>{values[item.id].comment}</p>}</div><b>{new Intl.NumberFormat("fr-FR").format(quantity(values[item.id].quantity))}</b></div>)}</div><div className="dialog-note"><Info size={17}/><span>Le nom de votre agence et les quantités seront ajoutés automatiquement aux commentaires du fichier consolidé.</span></div>{error && <div className="error-message" role="alert">{error}</div>}{!ready && <div className="error-message" role="alert">{sessionError || "Connexion au service d’enregistrement…"}<button className="text-button" onClick={() => void initialize(false)}>Réessayer</button></div>}<div className="dialog-actions"><button className="button secondary" disabled={busy} onClick={() => setReview(false)}><ArrowLeft size={16}/>Revenir à la saisie</button><button className="button primary" disabled={busy || !ready} onClick={() => void submit()}>{busy ? <><LoaderCircle className="spin" size={17}/>Envoi en cours…</> : <>Confirmer l’envoi<Send size={17}/></>}</button></div></section></div>}
  </>;
}
