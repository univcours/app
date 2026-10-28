import { createRoot } from "react-dom/client";
import NeedsApp from "../app/needs-app";
import AdminApp from "../app/gestion/admin-app";
import "../app/globals.css";

const management = new URLSearchParams(window.location.search).get("page") === "gestion";
createRoot(document.getElementById("root")!).render(management ? <AdminApp/> : <NeedsApp/>);
