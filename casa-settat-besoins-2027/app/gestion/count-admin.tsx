"use client";

import { useEffect, useRef, useState } from 'react';
import { Building2, CalendarDays, Check, ChevronDown, ClipboardList, Download, Link2, LoaderCircle, RefreshCw, Search, Trash2 } from 'lucide-react';
import { apiFetch, countingPath } from '../../lib/api-client';
import { conciseCountWorkbook } from '../../lib/count-excel-client.mjs';
import { DEFAULT_COUNT_MONTH, countTotals, dateLabel, monthLabel, validMonth } from '../../lib/comptage.mjs';
import { missingCountAgencies } from '../../lib/count-followup.mjs';
import { formatDate } from '../components';
import CountTable from '../comptage/count-table';
import type { CountSubmission } from '../comptage/types';
import DeleteDialog from './delete-dialog';

function labelAgencyRoute(agency:string) {
  return agency.replace(/ — tournée de distribution (10|[1-9])$/, (_match, number:string) => ` · Tournée N°: ${number}`);
}
export default function CountAdmin({onUnauthorized}:{onUnauthorized:()=>void}) {
  const [month,setMonth]=useState(DEFAULT_COUNT_MONTH), [responses,setResponses]=useState<CountSubmission[]>([]),[months,setMonths]=useState<string[]>([]);
  const [loading,setLoading]=useState(true),[loaded,setLoaded]=useState(false),[missingFilter,setMissingFilter]=useState(''),[openedMissing,setOpenedMissing]=useState<string|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState(''),[filter,setFilter]=useState(''),[opened,setOpened]=useState<string|null>(null),[exportAgency,setExportAgency]=useState(''),[copied,setCopied]=useState(false),[deleteTarget,setDeleteTarget]=useState<CountSubmission|null>(null),[feedback,setFeedback]=useState('');
  const generation=useRef(0);
  async function load(period:string){
    const ticket=++generation.current;setLoading(true);setLoaded(false);setError('');setResponses([]);setOpened(null);setOpenedMissing(null);setExportAgency('');
    try{
      const response=await apiFetch(`/api/admin/comptage/responses?month=${encodeURIComponent(period)}`,{cache:'no-store'});
      const data=await response.json() as {error?:string;responses:CountSubmission[];months:string[]};
      if(ticket!==generation.current)return;
      if(response.status===401){onUnauthorized();return;}
      if(!response.ok)throw new Error(data.error);
      setResponses(data.responses);setMonths(data.months);setLoaded(true);
    }catch(problem){if(ticket===generation.current)setError(problem instanceof Error?problem.message:'Chargement impossible.');}
    finally{if(ticket===generation.current)setLoading(false);}
  }
  useEffect(()=>{void load(month);},[month]);
  async function download(id=exportAgency){
    setBusy(true);setError('');
    try{
      const response=await apiFetch(`/api/admin/comptage/export?month=${encodeURIComponent(month)}${id?'&agency='+encodeURIComponent(id):''}`,{cache:'no-store'});
      if(!response.ok){const data=await response.json() as {error?:string};if(response.status===401)onUnauthorized();throw new Error(data.error);}
      const selected=id?responses.filter(row=>row.id===id):responses;
      const url=URL.createObjectURL(await conciseCountWorkbook(await response.blob(),selected)),link=document.createElement('a');
      link.href=url;link.download=/filename="([^"]+)"/.exec(response.headers.get('content-disposition')||'')?.[1]||`Comptage_${month}.xlsx`;
      document.body.appendChild(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
    }catch(problem){setError(problem instanceof Error?problem.message:'Téléchargement impossible.');}
    finally{setBusy(false);}
  }
  async function copy(){try{await navigator.clipboard.writeText(location.origin+countingPath);setCopied(true);setTimeout(()=>setCopied(false),2000);}catch{setError('Le lien de saisie figure dans le bouton « Ouvrir le formulaire » ci-dessus.');}}
  async function remove(){
    if(!deleteTarget||busy)return;setBusy(true);setError('');setFeedback('');
    try{
      const response=await apiFetch('/api/admin/comptage/delete',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id:deleteTarget.id,updatedAt:deleteTarget.updatedAt})});
      const data=await response.json() as {error?:string;id:string};
      if(!response.ok){if(response.status===401)onUnauthorized();throw new Error(data.error);}
      setResponses(previous=>previous.filter(row=>row.id!==data.id));if(exportAgency===data.id)setExportAgency('');if(opened===data.id)setOpened(null);
      setFeedback(`Le comptage de ${labelAgencyRoute(deleteTarget.agency)} pour ${monthLabel(month)} a été supprimé.`);
    }catch(problem){setError(problem instanceof Error?problem.message:'Suppression impossible.');}
    finally{setBusy(false);setDeleteTarget(null);}
  }
  const visible=responses.filter(response=>response.agency.toLocaleLowerCase('fr').includes(filter.toLocaleLowerCase('fr')));
  const missingAgencies=loaded ? missingCountAgencies(month,responses) : [];
  const visibleMissing=missingAgencies.filter(item=>item.agency.toLocaleLowerCase('fr').includes(missingFilter.toLocaleLowerCase('fr')));
  return <><div className="workspace-title"><div><span className="eyebrow muted">SUIVI MENSUEL DES AGENCES</span><h1>Comptage des envois.</h1><p>Chaque agence et son numéro de tournée, chaque journée, dans le canevas d’origine.</p></div><div className="count-admin-links"><a className="button secondary" href={countingPath}>Ouvrir le formulaire</a><button className="button secondary" onClick={()=>void copy()}>{copied?<Check size={16}/>:<Link2 size={16}/>} {copied?'Lien copié':'Copier le lien'}</button></div></div>
    <div className="count-admin-period"><div><label htmlFor="count-admin-month">Mois à consulter</label><input id="count-admin-month" type="month" min="2000-01" max="2099-12" value={month} onInput={event=>{if(validMonth(event.currentTarget.value))setMonth(event.currentTarget.value);}}/></div>{months.length>0&&<div><label htmlFor="count-received-months">Mois ayant reçu des comptages</label><select id="count-received-months" value={months.includes(month)?month:''} onChange={event=>{if(event.target.value)setMonth(event.target.value);}}><option value="">Choisir un mois reçu</option>{months.map(period=><option key={period} value={period}>{monthLabel(period)}</option>)}</select></div>}<button className="button secondary" disabled={loading} onClick={()=>void load(month)}><RefreshCw size={16} className={loading?'spin':''}/>Actualiser</button></div>
    <div className="admin-stats"><div><span className="soft-icon small"><Building2 size={20}/></span><span><strong>{responses.length}</strong><small>Tournées · {monthLabel(month)}</small></span></div><div><span className="soft-icon small"><CalendarDays size={20}/></span><span><strong>{responses.reduce((sum,response)=>sum+response.rows.filter(row=>row.values.some(value=>value!==null)).length,0)}</strong><small>Journées renseignées</small></span></div><div><span className="soft-icon small"><ClipboardList size={20}/></span><span><strong>14 rubriques</strong><small>Détail conservé par journée</small></span></div></div>
    <section className="export-card"><div><span className="eyebrow">CANEVAS EXCEL</span><h2>Le même modèle, rempli.</h2><p>Téléchargez le mois d’une agence ou toutes les agences. Le fichier contient une feuille par numéro de tournée avec les mêmes colonnes et les totaux du canevas.</p></div><div className="export-controls"><label htmlFor="count-export-agency">Périmètre de l’export · {monthLabel(month)}</label><select id="count-export-agency" value={exportAgency} onChange={event=>setExportAgency(event.target.value)}><option value="">Toutes les tournées · une feuille par tournée</option>{responses.map(row=><option key={row.id} value={row.id}>{row.agency}</option>)}</select><button className="button export-button" disabled={busy||loading||!responses.length} onClick={()=>void download()}>{busy?<LoaderCircle className="spin" size={18}/>:<Download size={18}/>}Télécharger le canevas Excel</button></div></section>
    {error&&<div className="error-message" role="alert">{error}</div>}{feedback&&<div className="notice" role="status"><Check size={16}/>{feedback}</div>}
    <section className="responses-panel"><div className="responses-toolbar"><div><h2>Comptages des agences <span>{responses.length}</span></h2><p>{monthLabel(month)}</p></div><div className="search-field"><Search size={17}/><input aria-label="Rechercher une agence de comptage" placeholder="Rechercher une agence…" value={filter} onChange={event=>setFilter(event.target.value)}/></div></div>
      {loading?<div className="count-loading" role="status"><LoaderCircle className="spin" size={24}/>Chargement des comptages…</div>:!visible.length?<div className="empty-state"><ClipboardList size={30}/><strong>{filter?'Aucune agence correspondante':'Aucun comptage reçu pour ce mois.'}</strong><p>Choisissez un autre mois ou partagez le formulaire avec vos agences.</p></div>:<div className="response-list">{visible.map(response=><article key={response.id} className="response-card"><div className="response-heading"><button className="response-summary" aria-expanded={opened===response.id} onClick={()=>setOpened(opened===response.id?null:response.id)}><span className="agency-initial">{response.agency.charAt(0).toUpperCase()}</span><span><strong>{labelAgencyRoute(response.agency)}</strong><small>{formatDate(response.updatedAt)}</small></span><b>{response.rows.filter(row=>row.values.some(value=>value!==null)).length} journées</b><ChevronDown size={17} className={opened===response.id?'rotated':''}/></button><button className="delete-agency-button" disabled={busy} aria-label={`Supprimer le comptage de ${response.agency} pour ${monthLabel(month)}`} onClick={()=>setDeleteTarget(response)}><Trash2 size={16}/><span>Supprimer</span></button></div>{opened===response.id&&<div className="count-admin-detail"><div className="count-detail-title"><strong>{labelAgencyRoute(response.agency)} · {monthLabel(month)}</strong><button className="button secondary" disabled={busy} onClick={()=>void download(response.id)}><Download size={15}/>Excel de cette agence</button></div><CountTable month={month} rows={response.rows}/><details className="count-totals-details"><summary>Totaux du mois, par rubrique</summary><dl>{countTotals(response.rows).map((value,index)=><div key={index}><dt>{['Lettres ordinaires','Paquets ordinaires','Autorités locales','Lettres recommandées','Paquets recommandés','E-BARKI@ distribué','LRH distribué','AMANA distribué','Recommandés avisés','E-BARKI@ avisés','LRH avisés','AMANA avisés','Tri en boîtes postales','Tri des avis en boîtes postales'][index]}</dt><dd>{new Intl.NumberFormat('fr-FR').format(value)}</dd></div>)}</dl></details></div>}</article>)}</div>}
    </section>
    <section className="responses-panel missing-agencies-panel">
      <div className="responses-toolbar">
        <div><h2>Agences à compléter <span>{loaded ? missingAgencies.length : '—'}</span></h2>
          <p>Journées non saisies · {monthLabel(month)} · cliquez sur une agence pour consulter les dates manquantes.</p></div>
        <div className="search-field"><Search size={17}/><input aria-label="Rechercher parmi les agences à compléter" placeholder="Rechercher une agence…" value={missingFilter} onChange={event=>setMissingFilter(event.target.value)}/></div>
      </div>
      {!loaded ? <div className="count-loading" role="status">{loading ? <><LoaderCircle className="spin" size={20}/>Vérification des saisies…</> : 'Impossible de vérifier les agences. Actualisez la liste.'}</div>
      : !visibleMissing.length ? <div className="empty-state"><Check size={24}/><strong>{missingFilter ? 'Aucune agence correspondante' : 'Toutes les agences ont complété les journées prévues.'}</strong></div>
      : <div className="missing-agencies-list">{visibleMissing.map(item=><article className="missing-agency-item" key={item.agency}>
          <button className="missing-agency-toggle" aria-expanded={openedMissing===item.agency} onClick={()=>setOpenedMissing(openedMissing===item.agency?null:item.agency)}>
            <span className="agency-initial">{item.agency.charAt(0)}</span>
            <span className="missing-agency-name"><strong>{item.agency}</strong><small>{item.received===0 ? 'Aucun comptage reçu pour ce mois' : `${item.received} tournée(s) transmise(s) · saisie incomplète`}</small></span>
            <span className="missing-agency-count">{item.missingCount} journée(s) non saisie(s)</span>
            <ChevronDown size={17} className={openedMissing===item.agency?'rotated':''}/>
          </button>
          {openedMissing===item.agency&&<div className="missing-agency-details">
            {item.routes.map((route,index)=><div key={route.tournee??'none'} className="missing-route">
              <strong>{route.tournee===null ? 'Aucune tournée transmise' : `Tournée N°: ${route.tournee}`}</strong>
              <p>{route.missing.length} date(s) non saisie(s) dans le canevas de {monthLabel(month)} :</p>
              <div className="missing-date-list">{route.missing.map(date=><span key={date} className="missing-date">{dateLabel(date)}</span>)}</div>
            </div>)}
            <small className="missing-hint">Seules les tournées déjà transmises peuvent être contrôlées individuellement. Les dates futures sont affichées comme non encore saisies, pas comme un retard.</small>
          </div>}
        </article>)}</div>}
    </section>
{deleteTarget&&<DeleteDialog agency={`${labelAgencyRoute(deleteTarget.agency)} · ${monthLabel(deleteTarget.month)}`} itemCount={deleteTarget.rows.length} kind="comptage" busy={busy} cancel={()=>{if(!busy)setDeleteTarget(null);}} confirm={()=>void remove()}/>}</>;
}
