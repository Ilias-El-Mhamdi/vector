// =============================================================================
//  State
// =============================================================================
let LEADS   = [];
let CATALOG = { products: [], options_globales: [] };
let CURRENT = null;

// =============================================================================
//  Data loading
// =============================================================================
async function loadCatalog() {
  try {
    CATALOG = await api('/api/catalog');

    buildPanel('ms-product-panel',
      (CATALOG.products || []).map(p => ({ v: p.name, l: p.name })),
      () => false);

    buildPanel('ms-status-panel', ALL_STATUSES, v => v !== 'ignore');

    const opts = new Set();
    (CATALOG.products || []).forEach(p => (p.options || []).forEach(o => opts.add(o.name)));
    (CATALOG.options_globales || []).forEach(o => opts.add(o.name));
    buildPanel('ms-option-panel', [...opts].map(n => ({ v: n, l: n })), () => false);

    buildPanel('ms-quote-panel', [
      { v: 'oui', l: 'Avec devis' },
      { v: 'non', l: 'Sans devis' },
    ], () => false);

  } catch (e) { toast('Catalogue: ' + e.message); }
}

async function loadLeads() {
  LEADS = await api('/api/leads');
  render();
}

async function scan() {
  await withBusy('Scan Outlook en cours…', async () => {
    await withOutlook(async () => {
      const n   = document.getElementById('scanCount').value || 50;
      const res = await api('/api/scan?count=' + n, { method: 'POST' });
      const q   = res.quotesSaved ? `, ${res.quotesSaved} devis sauvegardé(s)` : '';
      toast(`Scan: ${res.scanned} mails lus, ${res.created} nouveaux${q}`);
      await loadLeads();
    });
  });
}

// =============================================================================
//  Lead list
// =============================================================================
function render() {
  const search    = document.getElementById('fSearch').value.toLowerCase();
  const selProds  = getChecked('ms-product');
  const selStats  = getChecked('ms-status');
  const selOpts   = getChecked('ms-option');
  const selQuote  = getChecked('ms-quote');
  const list     = document.getElementById('leadlist');
  list.innerHTML = '';

  const filtered = LEADS.filter(l => {
    if (selStats.length && !selStats.includes(l.status)) return false;
    if (selProds.length && !selProds.some(p => (l.products || []).some(prod => (prod.name || prod) === p))) return false;
    if (selOpts.length  && !selOpts.some(o  => (l.options  || []).includes(o))) return false;
    if (selQuote.length === 1) {
      if (selQuote[0] === 'oui' && !l.hasQuote) return false;
      if (selQuote[0] === 'non' &&  l.hasQuote) return false;
    }
    if (search) {
      const hay = (fullName(l) + ' ' + l.email + ' ' + (l.subject || '')).toLowerCase();
      if (!hay.includes(search)) return false;
    }
    return true;
  });

  document.getElementById('countBadge').textContent =
    filtered.length + ' lead' + (filtered.length !== 1 ? 's' : '');

  if (filtered.length === 0) { list.innerHTML = '<div class="noquote">Aucun lead.</div>'; return; }

  const emailCount = {};
  LEADS.forEach(l => { emailCount[l.email] = (emailCount[l.email] || 0) + 1; });

  filtered.forEach(l => {
    const div     = document.createElement('div');
    div.className = 'leaditem' + (CURRENT && CURRENT.id === l.id ? ' active' : '');
    div.onclick   = () => openLead(l.id);
    div.innerHTML = renderLeadItem(l, emailCount);
    list.appendChild(div);
  });
}

async function openLead(id) {
  await withBusy('Chargement du lead…', async () => {
    const partial = LEADS.find(l => l.id === id);
    if (partial) { CURRENT = partial; }
    try {
      CURRENT = await api('/api/lead?id=' + encodeURIComponent(id));
      renderDetail();
      render();
      await tryMatchQuote();
      if (!CURRENT.replyDraft) loadTemplate();
    } catch (e) { toast('Erreur: ' + e.message); }
  });
}

// =============================================================================
//  Sidebar — collapse & resize
// =============================================================================
function toggleSidebar() {
  const sidebar = document.getElementById('sidebar');
  const btn     = document.getElementById('sidebarToggle');
  const resizer = document.getElementById('sidebarResizer');
  const collapsed = sidebar.classList.toggle('collapsed');
  btn.innerHTML = collapsed ? '&#8250;' : '&#8249;';
  btn.title     = collapsed ? 'Développer' : 'Réduire';
  resizer.classList.toggle('hidden', collapsed);
  if (collapsed) {
    sidebar._savedWidth = sidebar.style.width;
    sidebar.style.width = '36px';
  } else {
    sidebar.style.width = sidebar._savedWidth || '';
  }
}

(function () {
  const resizer = document.getElementById('sidebarResizer');
  const sidebar = document.getElementById('sidebar');
  let dragging = false, startX = 0, startW = 0;

  resizer.addEventListener('mousedown', function (e) {
    dragging = true;
    startX   = e.clientX;
    startW   = sidebar.offsetWidth;
    resizer.classList.add('dragging');
    sidebar.style.transition  = 'none';
    document.body.style.userSelect = 'none';
    document.body.style.cursor     = 'ew-resize';
    e.preventDefault();
  });

  document.addEventListener('mousemove', function (e) {
    if (!dragging) return;
    const newW = Math.max(220, startW + (e.clientX - startX));
    sidebar.style.width = newW + 'px';
  });

  document.addEventListener('mouseup', function () {
    if (!dragging) return;
    dragging = false;
    resizer.classList.remove('dragging');
    sidebar.style.transition  = '';
    document.body.style.userSelect = '';
    document.body.style.cursor     = '';
  });
})();

// =============================================================================
//  Init
// =============================================================================
document.addEventListener('click', e => {
  if (!e.target.closest('.mselect'))
    document.querySelectorAll('.mselect-panel.open').forEach(p => p.classList.remove('open'));
});

async function init() {
  document.getElementById('detail').innerHTML = `
    <div class="empty">
      <div style="font-size:32px">📬</div>
      <div>Connexion à Outlook en cours...</div>
      <div style="font-size:12px;opacity:.5;margin-top:6px">Merci de patienter</div>
    </div>`;
  try {
    await api('/api/connect-outlook', { method: 'POST' });
  } catch (e) {
    toast('Impossible de se connecter à Outlook : ' + e.message);
  }
  try {
    const cfg = await api('/api/config');
    if (cfg.scanCount)        document.getElementById('scanCount').value = cfg.scanCount;
    if (cfg.anthropicApiKey)   window._anthropicKey       = cfg.anthropicApiKey;
    if (cfg.devisCreateurMail) window._devisCreateurMail  = cfg.devisCreateurMail;
    if (cfg.replySignature)    window._replySignature     = cfg.replySignature.replace(/\\n/g, '\n');
  } catch (e) { /* non bloquant */ }
  await loadCatalog();
  await loadLeads();
  document.getElementById('detail').innerHTML = `
    <div class="empty">
      <div style="font-size:40px">📭</div>
      <div>Sélectionnez un lead, ou cliquez sur « Scanner Outlook ».</div>
    </div>`;
}

init();
