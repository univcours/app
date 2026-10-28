"use client";

import { useEffect, useRef, useState } from "react";
import { UNSENT_AR, UNSENT_FR } from "../lib/form-state.mjs";

export function useUnsentWarning(active: boolean) {
  const [exitHref, setExitHref] = useState<string | null>(null);
  const allowExit = useRef(false);
  const previousFocus = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (!active) { setExitHref(null); return; }
    function beforeUnload(event: BeforeUnloadEvent) {
      if (allowExit.current) return;
      event.preventDefault();
      // Browsers choose their own wording for the native close/reload prompt.
      // The full French/Arabic wording is shown in the in-page dialog as well.
      event.returnValue = `${UNSENT_FR}\n${UNSENT_AR}`;
    }
    function beforeLink(event: MouseEvent) {
      if (allowExit.current || event.defaultPrevented || event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
      const anchor = event.target instanceof Element ? event.target.closest<HTMLAnchorElement>("a[href]") : null;
      if (!anchor || anchor.hasAttribute("download") || (anchor.target && anchor.target !== "_self" && anchor.target !== "_top")) return;
      const target = new URL(anchor.href, window.location.href);
      if (!["http:", "https:"].includes(target.protocol)) return;
      if (target.origin === window.location.origin && target.pathname === window.location.pathname && target.search === window.location.search && target.hash) return;
      event.preventDefault();
      event.stopPropagation();
      previousFocus.current = anchor;
      setExitHref(target.href);
    }
    window.addEventListener("beforeunload", beforeUnload);
    document.addEventListener("click", beforeLink, true);
    return () => { window.removeEventListener("beforeunload", beforeUnload); document.removeEventListener("click", beforeLink, true); };
  }, [active]);

  function cancelExit() { setExitHref(null); previousFocus.current?.focus(); }
  function confirmExit() {
    if (!exitHref) return;
    allowExit.current = true;
    window.location.assign(exitHref);
    // If navigation fails or is cancelled elsewhere, retain protection.
    window.setTimeout(() => { allowExit.current = false; setExitHref(null); }, 1500);
  }
  return { exitHref, cancelExit, confirmExit };
}
