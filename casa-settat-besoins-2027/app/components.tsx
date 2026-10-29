import { ArrowUpRight, Building2, LockKeyhole } from "lucide-react";
import { formPath, managementPath, countingPath, countingManagementPath } from "../lib/api-client";

export function Brand({counting=false}:{counting?:boolean}) {
  return <a className="brand" href={counting ? countingPath : formPath} aria-label={counting ? 'Comptage des envois, accueil' : 'Besoins 2027, accueil'}><span className="brand-mark"><Building2 size={23} strokeWidth={1.7}/></span><span><strong>{counting ? 'Comptage' : 'Besoins'}<span className="brand-year">{counting ? 'Envois' : '2027'}</span></strong><small>DR Casablanca-Settat</small></span></a>;
}
export function Header({ admin = false, counting = false }: { admin?: boolean; counting?:boolean }) {
  return <header className="site-header"><div className="header-inner"><Brand counting={counting}/><nav className="header-links"><a className="module-link" href={counting ? formPath : countingPath}>{counting ? 'Besoins 2027' : 'Comptage des envois'}<ArrowUpRight size={13}/></a><span className="header-label">{admin ? <><LockKeyhole size={14}/> Espace coordinateur</> : counting ? <>Suivi mensuel</> : <>Budget d’investissement</>}</span></nav></div></header>;
}
export function Footer({counting=false}:{counting?:boolean}) {
  return <footer className="site-footer"><span>Direction régionale Casablanca-Settat</span><span>{counting ? 'Comptage des envois · mensuel' : 'Collecte des besoins · 2027'}</span><a href={counting ? countingManagementPath : managementPath} className="coordinator-link" aria-label="Espace coordinateur" title="Espace coordinateur"><LockKeyhole size={15}/></a></footer>;
}
export const formatDate = (date: string) => new Intl.DateTimeFormat("fr-FR", { timeZone: "Africa/Casablanca", day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }).format(new Date(date));
