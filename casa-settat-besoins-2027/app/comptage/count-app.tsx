"use client";

import { useEffect, useMemo, useRef, useState } from 'react';
import { ArrowLeft, ArrowRight, CalendarDays, Check, CheckCircle2, ClipboardList, FileSpreadsheet, Grid2X2, LoaderCircle, MapPin, Plus, Send, ShieldCheck, X } from 'lucide-react';
import { Header, Footer, formatDate } from '../components';
import { apiFetch, formPath } from '../../lib/api-client';
import { agencyKey } from '../../lib/validation.mjs';
import { COUNT_FIELDS, COUNT_GROUPS, DEFAULT_COUNT_MONTH, cleanCountAgency, countDraftRows, countFingerprint, countRowsToDraft, countTotals, dateLabel, monthDates, monthLabel, templateDates, validMonth, validateCountSubmission } from '../../lib/comptage.mjs';
import { useUnsentWarning } from '../use-unsent-warning';
import ExitWarning from '../exit-warning';
import CountTable from './count-table';
import type { CountDraft, CountRow, CountSubmission } from './types';

const STORAGE = 'casa-settat-comptage-v1';
const routeAgency = (agency:string,tournee:string) => `${agency} — tournée de distribution ${tournee}`;
const storageKey = (agency:string,month:string,tournee:string) => `${STORAGE}:${agencyKey(routeAgency(agency,tournee))}:${month}`;
const blankRow = () => ({frequency:'',values:COUNT_FIELDS.map(()=>'')});
const message = (error:unknown) => error instanceof Error ? error.message : 'Connexion impossible. Réessayez.';
type DraftRecord = { agency:string;month:string;draft:CountDraft;sentSnapshot:string;receipt:{id:string;updatedAt:string}|null };
function readDraft(agency:string,month:string,tournee:string): DraftRecord | null {
  try {
    const stored = JSON.parse(localStorage.getItem(storageKey(agency,month,tournee)) || 'null');
    if (!stored || typeof stored.agency !== 'string' || agencyKey(stored.agency) !== agencyKey(routeAgency(agency,tournee)) || stored.month !== month || !stored.draft || typeof stored.draft !== 'object') return null;
    const allowed = new Set(monthDates(month));
    const draft = Object.fromEntries(Object.entries(stored.draft).filter(([date,row])=>allowed.has(date) && !!row && typeof row === 'object' && typeof (row as {frequency?:unknown}).frequency === 'string' && Array.isArray((row as {values?:unknown}).values) && (row as {values:unknown[]}).values.length === COUNT_FIELDS.length && (row as {values:unknown[]}).values.every(value=>typeof value === 'string')));
    return {...stored,draft,sentSnapshot:typeof stored.sentSnapshot === 'string' ? stored.sentSnapshot : ''};
  } catch { return null; }
}

export default function CountApp() {
  const [agency,setAgency] = useState('');
  const [month,setMonth] = useState(DEFAULT_COUNT_MONTH);
  const [tournee,setTournee] = useState('');
  const [draft,setDraft] = useState<CountDraft>({});
  const [started,setStarted] = useState(false);
  const [booted,setBooted] = useState(false);
  const [ready,setReady] = useState(false);
  const [busy,setBusy] = useState(false);
  const [loading,setLoading] = useState(false);
  const [error,setError] = useState('');
  const [sessionError,setSessionError] = useState('');
  const [sentSnapshot,setSentSnapshot] = useState('');
  const [receipt,setReceipt] = useState<{id:string;updatedAt:string}|null>(null);
  const [success,setSuccess] = useState(false);
  const [review,setReview] = useState(false);
  const [tableView,setTableView] = useState(false);
  const [selectedDate,setSelectedDate] = useState(templateDates(DEFAULT_COUNT_MONTH)[0]);
  const [extraDate,setExtraDate] = useState('');
  const [saved,setSaved] = useState(false);
  const [pending,setPending] = useState<string[]>([]);
  const generation = useRef(0);
  const reviewBack = useRef<HTMLButtonElement>(null);
  const snapshot = useMemo(()=>countFingerprint(routeAgency(agency,tournee),month,draft),[agency,tournee,month,draft]);
  const hasUnsent = booted && (!!agency.trim() || Object.keys(draft).length > 0) && snapshot !== sentSnapshot;
  const {exitHref,cancelExit,confirmExit} = useUnsentWarning(hasUnsent || pending.length > 0);
  const dates = [...new Set([...templateDates(month),...Object.keys(draft)])].sort();
  const selected = dates.includes(selectedDate) ? selectedDate : dates[0];
  const day = draft[selected] || blankRow();
  const filledDays = Object.values(draft).filter(row=>row.values.some(value=>value !== '')).length;
  const rowsForTotals = countDraftRows(draft).map(row=>({...row,values:row.values.map((value:number|null)=>value !== null && Number.isFinite(value) ? value : null)})) as CountRow[];
  const totals = countTotals(rowsForTotals);

  async function openMonth(name:string,period:string,selectedTournee=tournee) {
    let clean:string;
    try { clean=cleanCountAgency(name); if (!validMonth(period)) throw new Error('Choisissez un mois valide.'); if(!/^(10|[1-9])$/.test(selectedTournee)) throw new Error('Choisissez un numéro de tournée entre 1 et 10.'); if(routeAgency(clean,selectedTournee).length>100) throw new Error('Le nom de l’agence est trop long.'); }
    catch (problem) { setError(message(problem)); return; }
    const ticket=++generation.current, stored=readDraft(clean,period,selectedTournee);
    const keepDraft = !!stored && countFingerprint(routeAgency(clean,selectedTournee),period,stored.draft) !== stored.sentSnapshot;
    setAgency(clean);setTournee(selectedTournee);setMonth(period);setDraft(stored?.draft || {});setSentSnapshot(stored?.sentSnapshot || '');setReceipt(stored?.receipt || null);
    setSelectedDate(templateDates(period)[0]);setExtraDate('');setStarted(true);setSuccess(false);setError('');setSessionError('');setReady(false);setLoading(true);
    try {
      const response=await apiFetch(`/api/comptage/session?month=${encodeURIComponent(period)}&agency=${encodeURIComponent(routeAgency(clean,selectedTournee))}`,{cache:'no-store'});
      const data=await response.json() as {error?:string;submission:CountSubmission|null};
      if (ticket !== generation.current) return;
      if (!response.ok) throw new Error(data.error);
      if (data.submission) {
        const restored=countRowsToDraft(data.submission.rows) as CountDraft;
        setSentSnapshot(countFingerprint(routeAgency(clean,selectedTournee),period,restored));
        setReceipt({id:data.submission.id,updatedAt:data.submission.updatedAt});
        if (!keepDraft) setDraft(restored);
      } else {setSentSnapshot('');setReceipt(null);}
      setReady(true);
    } catch (problem) {if(ticket === generation.current)setSessionError(message(problem));}
    finally {if(ticket === generation.current)setLoading(false);}
  }
  useEffect(()=>{
    try {
      const last=JSON.parse(localStorage.getItem(STORAGE + ':last') || 'null');
      if(last && typeof last.agency === 'string' && /^(10|[1-9])$/.test(last.tournee || '') && validMonth(last.month)) void openMonth(last.agency,last.month,last.tournee);
    } catch {}
    setBooted(true);
  },[]);
  useEffect(()=>{
    if(!booted || !started) return;
    try {
      localStorage.setItem(storageKey(agency,month,tournee),JSON.stringify({agency:routeAgency(agency,tournee),month,tournee,draft,sentSnapshot,receipt}));
      localStorage.setItem(STORAGE + ':last',JSON.stringify({agency,month,tournee}));
      const prefix=STORAGE + ':' + agencyKey(routeAgency(agency,tournee)) + ':', unsent:string[]=[];
      for(let index=0;index<localStorage.length;index++) {
        const key=localStorage.key(index);
        if(!key?.startsWith(prefix))continue;
        const period=key.slice(prefix.length), record=readDraft(agency,period,tournee);
        if(record && Object.values(record.draft).some(row=>row.values.some(value=>value !== '') || row.frequency !== '') && countFingerprint(routeAgency(agency,tournee),period,record.draft) !== record.sentSnapshot)unsent.push(period);
      }
      unsent.sort();setPending(previous=>previous.join()===unsent.join() ? previous : unsent);setSaved(true);
    }catch{setSaved(false);}
  },[agency,tournee,month,draft,sentSnapshot,receipt,booted,started]);
  useEffect(()=>{
    if(!review)return;
    reviewBack.current?.focus();
    const previous=document.body.style.overflow;document.body.style.overflow='hidden';
    function keydown(event:KeyboardEvent){
      if(event.key==='Escape'&&!busy)setReview(false);
      if(event.key==='Tab'){
        const buttons=Array.from(document.querySelectorAll<HTMLButtonElement>('.count-review button:not(:disabled)'));
        const first=buttons[0],last=buttons[buttons.length-1];
        if(event.shiftKey&&document.activeElement===first){event.preventDefault();last?.focus();}
        else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first?.focus();}
      }
    }
    window.addEventListener('keydown',keydown);
    return()=>{document.body.style.overflow=previous;window.removeEventListener('keydown',keydown);};
  },[review,busy]);

  function change(date:string,index:number,value:string){
    setDraft(previous=>{const row=previous[date] || blankRow();return {...previous,[date]:index===-1 ? {...row,frequency:value} : {...row,values:row.values.map((old,column)=>column===index ? value : old)}};});
    setError('');setSuccess(false);
  }
  function prepareReview(){
    try{validateCountSubmission({agency:routeAgency(agency,tournee),month,rows:countDraftRows(draft)});setError('');setReview(true);}
    catch(problem){setError(message(problem));}
  }
  async function submit(){
    if(busy || !ready)return;
    setBusy(true);setError('');
    try{
      const payload=validateCountSubmission({agency:routeAgency(agency,tournee),month,rows:countDraftRows(draft)});
      const response=await apiFetch('/api/comptage/submit',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
      const data=await response.json() as {error?:string;id:string;updatedAt:string};
      if(!response.ok)throw new Error(data.error);
      setSentSnapshot(snapshot);setReceipt({id:data.id,updatedAt:data.updatedAt});setReview(false);setSuccess(true);
    }catch(problem){setError(message(problem));}
    finally{setBusy(false);}
  }

  return <><Header counting/><main className={started ? 'workspace-main count-main' : 'welcome-main'}>
    {!started ? <div className="welcome-grid"><section className="welcome-story"><span className="eyebrow">DR CASABLANCA-SETTAT</span><h1>Le comptage des envois,<br/><em>mois par mois.</em></h1><p>Renseignez les volumes quotidiens de votre agence dans le canevas de comptage. Votre coordinateur reçoit le détail de chaque journée.</p><div className="welcome-facts"><span><CalendarDays size={16}/>Suivi mensuel</span><span><FileSpreadsheet size={16}/>Canevas Excel conservé</span></div><div className="welcome-steps"><div><b>01</b>Indiquez l’agence et la tournée</div><div><b>02</b>Renseignez les journées</div><div><b>03</b>Envoyez votre mois</div></div><a className="count-story-link" href={formPath}><ArrowLeft size={14}/>Revenir aux besoins 2027</a></section><section className="welcome-form-card"><span className="soft-icon"><MapPin size={25}/></span><span className="eyebrow muted">COMPTAGE DES ENVOIS</span><h2>Votre agence et votre tournée.</h2><p>Les valeurs vides restent vides. Saisissez 0 lorsque le nombre d’envois est nul.</p><form onSubmit={event=>{event.preventDefault();void openMonth(agency,month,tournee);}}><label htmlFor="count-agency">Nom de l’agence <span className="required">*</span></label><input id="count-agency" required minLength={2} maxLength={68} autoComplete="organization" placeholder="Ex. Agence Oulad Frej" value={agency} onChange={event=>setAgency(event.target.value)}/><label htmlFor="count-tournee">Tournée N°: <span className="required">*</span></label><select id="count-tournee" required value={tournee} onChange={event=>setTournee(event.target.value)}><option value="">Choisir une tournée</option>{Array.from({length:10},(_,index)=>index+1).map(value=><option key={value} value={String(value)}>Tournée {value}</option>)}</select><label className="count-month-label" htmlFor="count-month-start">Mois du comptage <span className="required">*</span></label><input id="count-month-start" type="month" required min="2000-01" max="2099-12" value={month} onInput={event=>setMonth(event.currentTarget.value)}/>{error&&<div className="error-message" role="alert">{error}</div>}<button type="submit" className="button primary full">Ouvrir le canevas<ArrowRight size={16}/></button></form><p className="privacy-note"><ShieldCheck size={16}/>Votre saisie reste un brouillon sur cet appareil jusqu’à la confirmation de l’envoi.</p></section></div>
    : success ? <section className="success-card"><span className="success-icon"><CheckCircle2 size={38}/></span><span className="eyebrow muted">COMPTAGE TRANSMIS</span><h1>Votre mois a bien été envoyé.</h1><p>{agency} · Tournée N°: {tournee} · {monthLabel(month)}</p><div className="receipt-summary"><span>{filledDays} journée{filledDays>1?'s':''} renseignée{filledDays>1?'s':''}</span><span>{receipt&&formatDate(receipt.updatedAt)}</span></div><p className="success-next">Le coordinateur peut consulter les détails et télécharger votre canevas Excel.</p><div className="count-success-actions"><button className="button primary" onClick={()=>setSuccess(false)}>Consulter ou modifier ce mois</button><button className="button secondary" onClick={()=>{const next=new Date(month+'-01T12:00:00Z');next.setUTCMonth(next.getUTCMonth()+1);void openMonth(agency,next.toISOString().slice(0,7));}}>Passer au mois suivant<ArrowRight size={16}/></button></div></section>
    : <><div className="workspace-title"><div><span className="eyebrow muted">COMPTAGE DES ENVOIS</span><h1>{agency} · Tournée N°: {tournee}</h1><p>Les mêmes rubriques que votre canevas Excel, une journée à la fois.</p></div><button className="button secondary" onClick={()=>setStarted(false)}><MapPin size={15}/>Changer d’agence</button></div>
      <div className="count-toolbar"><div><label htmlFor="count-month">Mois du comptage</label><input id="count-month" type="month" min="2000-01" max="2099-12" value={month} disabled={loading||busy} onInput={event=>{if(validMonth(event.currentTarget.value))void openMonth(agency,event.currentTarget.value);}}/></div><div className="count-view-toggle" aria-label="Mode de saisie"><button className={!tableView?'active':''} aria-pressed={!tableView} onClick={()=>setTableView(false)}><CalendarDays size={15}/>Par journée</button><button className={tableView?'active':''} aria-pressed={tableView} onClick={()=>setTableView(true)}><Grid2X2 size={15}/>Canevas complet</button></div><div className="count-completion"><strong>{filledDays}</strong> journée{filledDays>1?'s':''} renseignée{filledDays>1?'s':''}</div></div>
      {pending.filter(period=>period!==month).length>0&&<div className="notice count-pending"><ClipboardList size={16}/><span>Brouillons non envoyés : {pending.filter(period=>period!==month).map(period=><button className="text-button" key={period} onClick={()=>void openMonth(agency,period)}>{monthLabel(period)}</button>)}</span></div>}
      {receipt&&<div className="notice"><Check size={16}/><span>Dernier envoi de ce mois : {formatDate(receipt.updatedAt)}. Vos modifications seront transmises après confirmation.</span></div>}
      {sessionError&&<div className="error-message connection-error" role="alert"><span>{sessionError}</span><button className="text-button" onClick={()=>void openMonth(agency,month)}>Réessayer la connexion</button></div>}
      <p className="count-input-help">Saisissez des nombres entiers. Une case vide signifie « non renseigné » ; 0 signifie « aucun envoi ». La fréquence est requise pour chaque journée renseignée.</p>
      {loading?<div className="count-loading" role="status"><LoaderCircle className="spin" size={23}/>Ouverture du mois…</div>:tableView?<CountTable month={month} draft={draft} onChange={change}/>:<section className="count-day-editor"><div className="count-day-navigation"><button className="icon-button" aria-label="Journée précédente" disabled={dates.indexOf(selected)<=0} onClick={()=>setSelectedDate(dates[dates.indexOf(selected)-1])}><ArrowLeft size={18}/></button><div><label htmlFor="count-day">Journée du comptage</label><select id="count-day" value={selected} onChange={event=>setSelectedDate(event.target.value)}>{dates.map(date=><option key={date} value={date}>{dateLabel(date)}{draft[date]?.values.some(value=>value!=='')?' · renseigné':''}</option>)}</select></div><button className="icon-button" aria-label="Journée suivante" disabled={dates.indexOf(selected)>=dates.length-1} onClick={()=>setSelectedDate(dates[dates.indexOf(selected)+1])}><ArrowRight size={18}/></button></div><div className="count-frequency"><label htmlFor="count-frequency">Fréquence de distribution <span className="required">*</span></label><select id="count-frequency" value={day.frequency} onChange={event=>change(selected,-1,event.target.value)}><option value="">Choisir une fréquence</option>{[1,2,3,4,5].map(value=><option key={value} value={value}>{value}/5</option>)}</select></div><div className="count-field-groups">{COUNT_GROUPS.map((group,groupIndex)=>{const offset=COUNT_GROUPS.slice(0,groupIndex).reduce((sum,item)=>sum+item.count,0);return <fieldset key={group.label}><legend>{group.label}</legend>{COUNT_FIELDS.slice(offset,offset+group.count).map((field,index)=><div className="count-field" key={field}><label htmlFor={`count-value-${offset+index}`}>{field}</label><input id={`count-value-${offset+index}`} type="number" inputMode="numeric" min="0" max="10000000" step="1" placeholder="—" value={day.values[offset+index]} onChange={event=>change(selected,offset+index,event.target.value)}/></div>)}</fieldset>;})}</div><div className="count-day-footer"><span>{dateLabel(selected)} · {day.values.filter(value=>value!=='').length} / 14 rubriques renseignées</span><button className="button secondary" disabled={dates.indexOf(selected)>=dates.length-1} onClick={()=>setSelectedDate(dates[dates.indexOf(selected)+1])}>Journée suivante<ArrowRight size={15}/></button></div></section>}
      <div className="count-add-date"><label htmlFor="count-extra-date">Ajouter une date hors du canevas proposé</label><div><select id="count-extra-date" value={extraDate} onChange={event=>setExtraDate(event.target.value)}><option value="">Choisir une date du mois</option>{monthDates(month).filter(date=>!dates.includes(date)).map(date=><option key={date} value={date}>{dateLabel(date)}</option>)}</select><button className="button secondary" disabled={!extraDate} onClick={()=>{setDraft(previous=>({...previous,[extraDate]:blankRow()}));setSelectedDate(extraDate);setExtraDate('');setTableView(false);}}><Plus size={15}/>Ajouter</button></div><small>{month===DEFAULT_COUNT_MONTH?'Les dates proposées correspondent au canevas de novembre 2026.':'Les dates proposées vont du lundi au vendredi. Ajoutez une autre date si nécessaire.'}</small></div>
      {error&&<div className="error-message" role="alert">{error}</div>}<div className="submit-bar"><div><strong><span className="count-disc">{filledDays}</span>{monthLabel(month)}</strong><span className="local-save">{saved?<><Check size={12}/>Brouillon conservé sur cet appareil</>:<>L’enregistrement local est indisponible sur cet appareil.</>}</span></div><button className="button primary" disabled={busy||loading} onClick={prepareReview}><Send size={16}/>Vérifier et envoyer le mois</button></div>
    </>}
  </main><Footer counting/>
    {review&&<div className="modal-backdrop"><section className="review-dialog count-review" role="dialog" aria-modal="true" aria-labelledby="count-review-title"><div className="dialog-header"><div><span className="eyebrow muted">VÉRIFICATION DU COMPTAGE</span><h2 id="count-review-title">Envoyer {monthLabel(month)} ?</h2><p>{agency} · Tournée N°: {tournee} · {filledDays} journée{filledDays>1?'s':''} renseignée{filledDays>1?'s':''}</p></div><button className="icon-button" disabled={busy} aria-label="Fermer la vérification" onClick={()=>setReview(false)}><X size={18}/></button></div><div className="count-review-totals">{COUNT_FIELDS.map((field,index)=><div key={field}><span>{field}</span><strong>{new Intl.NumberFormat('fr-FR').format(totals[index])}</strong></div>)}</div><p className="dialog-note">Les totaux additionnent uniquement les nombres saisis. Les cases vides restent non renseignées. Cet envoi remplace votre précédent comptage pour cette agence et ce mois.</p>{error&&<div className="error-message" role="alert">{error}</div>}{!ready&&<div className="error-message" role="alert">La connexion doit être rétablie avant l’envoi.</div>}<div className="dialog-actions"><button ref={reviewBack} className="button secondary" disabled={busy} onClick={()=>setReview(false)}>Revenir à la saisie</button><button className="button primary" disabled={busy||!ready} onClick={()=>void submit()}>{busy?<LoaderCircle className="spin" size={16}/>:<Send size={16}/>}Confirmer l’envoi du mois</button></div></section></div>}
    {exitHref&&<ExitWarning cancel={cancelExit} leave={confirmExit}/>} 
  </>;
}
