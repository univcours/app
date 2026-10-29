import { createRoot } from "react-dom/client";
import NeedsApp from "../app/needs-app";
import AdminApp from "../app/gestion/admin-app";
import CountApp from "../app/comptage/count-app";
import "../app/globals.css";

const page = new URLSearchParams(window.location.search).get("page");
if(page === 'comptage') document.title='Comptage des envois · Casablanca-Settat';
createRoot(document.getElementById("root")!).render(page === 'gestion-comptage' ? <AdminApp initialSection="comptage"/> : page === 'gestion' ? <AdminApp/> : page === 'comptage' ? <CountApp/> : <NeedsApp/>);
