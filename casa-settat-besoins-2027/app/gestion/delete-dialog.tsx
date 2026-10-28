"use client";

import { useEffect, useRef } from "react";
import { LoaderCircle, Trash2, X } from "lucide-react";

export default function DeleteDialog({ agency, itemCount, busy, cancel, confirm }: { agency: string; itemCount: number; busy: boolean; cancel: () => void; confirm: () => void }) {
  const dialog = useRef<HTMLElement>(null);
  const cancelButton = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    cancelButton.current?.focus();
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    function keydown(event: KeyboardEvent) {
      if (event.key === "Escape" && !busy) cancel();
      if (event.key === "Tab") {
        const buttons = Array.from(dialog.current?.querySelectorAll<HTMLButtonElement>("button:not(:disabled)") || []);
        const first = buttons[0], last = buttons[buttons.length - 1];
        if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
        if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
      }
    }
    window.addEventListener("keydown", keydown);
    return () => { document.body.style.overflow = previous; window.removeEventListener("keydown", keydown); };
  }, [busy, cancel]);
  return <div className="modal-backdrop" onClick={event => { if (event.target === event.currentTarget && !busy) cancel(); }}><section ref={dialog} className="delete-dialog" role="dialog" aria-modal="true" aria-labelledby="delete-title" aria-describedby="delete-description"><div className="dialog-header"><span className="delete-warning-icon"><Trash2 size={24}/></span><button className="icon-button" disabled={busy} aria-label="Annuler la suppression" onClick={cancel}><X size={19}/></button></div><h2 id="delete-title">Supprimer cette demande ?</h2><div className="delete-agency"><strong>{agency}</strong><span>{itemCount} article{itemCount > 1 ? "s" : ""} renseigné{itemCount > 1 ? "s" : ""}</span></div><p id="delete-description">Les besoins de cette agence seront retirés de la liste et des prochains exports Excel. Cette suppression est définitive.</p><div className="dialog-actions"><button ref={cancelButton} className="button secondary" disabled={busy} onClick={cancel}>Annuler</button><button className="button danger-button" disabled={busy} onClick={confirm}>{busy ? <LoaderCircle className="spin" size={17}/> : <Trash2 size={17}/>} {busy ? "Suppression…" : "Supprimer la demande"}</button></div></section></div>;
}
