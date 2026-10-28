"use client";

import { useEffect, useRef } from "react";
import { AlertTriangle, ArrowLeft, X } from "lucide-react";
import { UNSENT_AR, UNSENT_FR } from "../lib/form-state.mjs";

export default function ExitWarning({ cancel, leave }: { cancel: () => void; leave: () => void }) {
  const dialogRef = useRef<HTMLElement>(null);
  const continueRef = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    continueRef.current?.focus();
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    function keydown(event: KeyboardEvent) {
      if (event.key === "Escape") { event.preventDefault(); cancel(); }
      if (event.key === "Tab") {
        const buttons = Array.from(dialogRef.current?.querySelectorAll<HTMLButtonElement>("button") || []);
        const first = buttons[0], last = buttons[buttons.length - 1];
        if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
        if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
      }
    }
    window.addEventListener("keydown", keydown);
    return () => { document.body.style.overflow = previous; window.removeEventListener("keydown", keydown); };
  }, [cancel]);

  return <div className="modal-backdrop exit-backdrop" onClick={event => { if (event.target === event.currentTarget) cancel(); }}><section ref={dialogRef} className="exit-dialog" role="dialog" aria-modal="true" aria-labelledby="exit-title" aria-describedby="exit-fr exit-ar"><div className="dialog-header"><span className="exit-warning-icon"><AlertTriangle size={24}/></span><button className="icon-button" aria-label="Continuer la saisie / متابعة التعبئة" onClick={cancel}><X size={19}/></button></div><h2 id="exit-title">Cette version de votre demande n’a pas été envoyée.</h2><h3 lang="ar" dir="rtl">لم يتم إرسال هذه النسخة من طلبكم بعد.</h3><p id="exit-fr" lang="fr">{UNSENT_FR}</p><p id="exit-ar" lang="ar" dir="rtl">{UNSENT_AR}</p><div className="exit-actions"><button ref={continueRef} className="button primary" onClick={cancel}><ArrowLeft size={16}/><span>Continuer la saisie<small lang="ar" dir="rtl">متابعة التعبئة</small></span></button><button className="button leave-button" onClick={leave}><span>Quitter sans envoyer<small lang="ar" dir="rtl">الخروج دون إرسال</small></span></button></div></section></div>;
}
