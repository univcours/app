import { createRoot } from "react-dom/client";
import AdminApp from "../app/gestion/admin-app";
import CountApp from "../app/comptage/count-app";
import "../app/globals.css";

const page = new URLSearchParams(window.location.search).get("page");
document.title='Comptage des envois · Casablanca-Settat';
// Keep the previous Besoins data and API intact but show only the monthly comptage module.
createRoot(document.getElementById("root")!).render(page === 'gestion-comptage' || page === 'gestion' ? <AdminApp initialSection="comptage"/> : <CountApp/>);
