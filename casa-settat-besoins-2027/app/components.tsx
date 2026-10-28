import { ArrowUpRight, Building2, LockKeyhole } from "lucide-react";

export function Brand() {
  return <a className="brand" href="/" aria-label="Besoins 2027, accueil"><span className="brand-mark"><Building2 size={23} strokeWidth={1.7}/></span><span><strong>Besoins<span className="brand-year">2027</span></strong><small>DR Casablanca-Settat</small></span></a>;
}
export function Header({ admin = false }: { admin?: boolean }) {
  return <header className="site-header"><div className="header-inner"><Brand/><span className="header-label">{admin ? <><LockKeyhole size={14}/> Espace coordinateur</> : <>Budget d’investissement <ArrowUpRight size={14}/></>}</span></div></header>;
}
export function Footer() {
  return <footer className="site-footer"><span>Direction régionale Casablanca-Settat</span><span>Collecte des besoins · 2027</span><a href="/gestion" className="coordinator-link" aria-label="Espace coordinateur" title="Espace coordinateur"><LockKeyhole size={15}/></a></footer>;
}
export const formatDate = (date: string) => new Intl.DateTimeFormat("fr-FR", { timeZone: "Africa/Casablanca", day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }).format(new Date(date));
