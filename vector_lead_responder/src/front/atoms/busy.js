let BUSY = false;

async function withBusy(label, fn) {
  if (BUSY) return;
  BUSY = true;
  _busyOverlay(true, label);
  try { return await fn(); }
  finally { BUSY = false; _busyOverlay(false); }
}

function _busyOverlay(show, label) {
  let el = document.getElementById('_busyOverlay');
  if (!el) {
    if (!document.getElementById('_busyStyle')) {
      const style = document.createElement('style');
      style.id = '_busyStyle';
      style.textContent = `
        @keyframes _bSpin { to { transform: rotate(360deg); } }
        #_busySpinner::after {
          content: ''; display: inline-block; width: 22px; height: 22px;
          border: 3px solid var(--line, #333); border-top-color: var(--accent, #4f9cf9);
          border-radius: 50%; animation: _bSpin .7s linear infinite;
        }`;
      document.head.appendChild(style);
    }
    el = document.createElement('div');
    el.id = '_busyOverlay';
    Object.assign(el.style, {
      position: 'fixed', inset: '0',
      background: 'rgba(0,0,0,.45)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      zIndex: '9998',
      cursor: 'wait'
    });
    el.innerHTML = `
      <div style="background:var(--panel,#1e1e2e);border:1px solid var(--line,#333);
                  border-radius:12px;padding:22px 34px;text-align:center;
                  box-shadow:0 8px 32px rgba(0,0,0,.4);display:flex;align-items:center;gap:16px">
        <div id="_busySpinner"></div>
        <div id="_busyLabel" style="font-size:14px;color:var(--txt,#eee);font-weight:500"></div>
      </div>`;
    document.body.appendChild(el);
  }
  if (show) {
    document.getElementById('_busyLabel').textContent = label || '';
    el.style.display = 'flex';
  } else {
    el.style.display = 'none';
  }
}
