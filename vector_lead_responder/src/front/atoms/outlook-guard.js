// ─── Outlook connection guard ────────────────────────────────────────────────
// withOutlook(fn) : vérifie que la connexion COM est vivante avant d'exécuter
// fn(). Si elle est morte, affiche un overlay bloquant et reconnecte d'abord.

async function withOutlook(fn) {
  let connected = false;
  try {
    const st = await fetch('/api/outlook-status').then(r => r.json());
    connected = !!st.connected;
  } catch {}

  if (!connected) {
    _outlookOverlay(true);
    try {
      await fetch('/api/connect-outlook', { method: 'POST' });
    } catch (e) {
      _outlookOverlay(false);
      toast('❌ Connexion Outlook échouée : ' + (e.message || e));
      return;
    }
    _outlookOverlay(false);
  }

  return fn();
}

function _outlookOverlay(show) {
  let el = document.getElementById('_outlookOverlay');
  if (!el) {
    if (!document.getElementById('_outlookStyle')) {
      const style = document.createElement('style');
      style.id = '_outlookStyle';
      style.textContent = `
        @keyframes _olSpin { to { transform: rotate(360deg); } }
        #_outlookSpinner::after {
          content: ''; display: inline-block; width: 28px; height: 28px;
          border: 3px solid var(--line, #333); border-top-color: var(--accent, #4f9cf9);
          border-radius: 50%; animation: _olSpin .8s linear infinite;
        }`;
      document.head.appendChild(style);
    }
    el = document.createElement('div');
    el.id = '_outlookOverlay';
    Object.assign(el.style, {
      position: 'fixed', inset: '0',
      background: 'rgba(0,0,0,.6)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      zIndex: '9999'
    });
    el.innerHTML = `
      <div style="background:var(--panel,#1e1e2e);border:1px solid var(--line,#333);
                  border-radius:14px;padding:36px 44px;text-align:center;
                  max-width:380px;box-shadow:0 12px 40px rgba(0,0,0,.5)">
        <div style="font-size:40px;margin-bottom:14px">📬</div>
        <div style="font-size:15px;font-weight:600;margin-bottom:8px;color:var(--txt,#eee)">
          Connexion à Outlook en cours…
        </div>
        <div style="font-size:12px;opacity:.6;line-height:1.5;color:var(--txt,#eee)">
          Veuillez patienter,<br>cela peut prendre jusqu'à 2 minutes.
        </div>
        <div style="margin-top:24px" id="_outlookSpinner"></div>
      </div>`;
    document.body.appendChild(el);
  }
  el.style.display = show ? 'flex' : 'none';
}
