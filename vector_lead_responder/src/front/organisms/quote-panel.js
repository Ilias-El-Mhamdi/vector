function defaultQuoteDraft(l) {
  const name     = fullName(l) || l.email;
  const prodLines = (l.products || []).map(p => {
    const n = p.name || p;
    const q = p.quantity || 1;
    return `- ${q} ${n}`;
  }).join('\n') || '- —';
  const optLines = (l.options || []).map(o => `- ${o}`).join('\n') || '- —';
  return `Bonjour,\n\nMerci de bien vouloir établir un devis pour le client suivant :\n\nClient  : ${name}\nE-mail  : ${l.email}\n\nProduits :\n${prodLines}\n\nOptions :\n${optLines}`;
}

function renderQuoteCard(l) {
  const quoteSrc  = '/api/file?id=' + encodeURIComponent(l.id) + '&name=' + encodeURIComponent(l.quoteName || '') + '&t=' + Date.now();
  const draftContent = l.quoteDraft !== undefined && l.quoteDraft !== null ? l.quoteDraft : defaultQuoteDraft(l);
  const quoteHtml = l.hasQuote
    ? `<iframe class="quoteframe" src="${quoteSrc}"></iframe>`
    : `<div style="padding:14px;display:flex;flex-direction:column;gap:10px">
        <textarea id="quoteDraftBox" class="reply" style="min-height:180px" oninput="scheduleQuoteDraftSave()">${esc(draftContent)}</textarea>
        <div class="toolbar" style="justify-content:flex-end">
          <button class="btn ghost" onclick="searchQuote()" id="searchQuoteBtn">🔍 Rechercher devis</button>
          <button class="btn ghost" onclick="previewQuote()">👁 Voir dans Outlook</button>
          <button class="btn green" onclick="generateQuote()">📋 Générer devis</button>
        </div>
      </div>`;

  const draftPanel = l.hasQuote
    ? `<div style="padding:14px;border-top:1px solid var(--line)">
        <p style="font-size:11px;color:var(--muted);margin:0 0 6px">Demande de devis envoyée en interne :</p>
        <pre style="margin:0;white-space:pre-wrap;font-size:12px;line-height:1.5;color:var(--txt)">${esc(draftContent)}</pre>
      </div>`
    : '';

  return `
    <div class="card">
      <h3 style="display:flex;align-items:center;justify-content:space-between">📄 Devis (aperçu)<span style="display:flex;gap:4px"><button class="btn ghost" style="font-size:11px;padding:2px 8px" onclick="resetQuoteDraft()" title="Réappliquer le template">↺ Template</button><button class="btn ghost" style="font-size:11px;padding:2px 8px" onclick="aiQuoteDraft()" title="Générer avec l\'IA">✦ IA Template</button></span></h3>
      <div id="quoteBody" class="body" style="padding:0">${quoteHtml}</div>
      <div id="quoteDrop"
        ondragover="quoteDragOver(event)" ondragleave="quoteDragLeave(event)" ondrop="quoteDrop(event)"
        onclick="document.getElementById('quoteFileInput').click()"
        style="margin:10px;border:2px dashed var(--line);border-radius:8px;padding:10px 14px;text-align:center;color:var(--muted);font-size:12px;cursor:pointer;transition:border-color .15s,background .15s">
        📎 Déposer un PDF ici ou <span style="color:var(--accent);text-decoration:underline">parcourir</span>
      </div>
      <input id="quoteFileInput" type="file" accept=".pdf" style="display:none" onchange="quoteFileSelected(this)">
      ${draftPanel}
    </div>`;
}


async function deleteQuoteAndReset(applyFn) {
  if (!CURRENT) return;
  if (CURRENT.hasQuote) {
    if (!confirm('Un devis est déjà associé à ce lead.\n\nSupprimer le devis et réinitialiser le template ?')) return;
    await withBusy('Suppression du devis…', async () => {
      try {
        const res = await apiPdf('/api/delete-quote?id=' + encodeURIComponent(CURRENT.id), { method: 'POST' });
        CURRENT.hasQuote  = false;
        CURRENT.quoteName = '';
        CURRENT.status    = res.status;
        renderDetail();
        await loadLeads();
      } catch (e) { toast('Erreur suppression devis : ' + e.message); return; }
    });
  }
  applyFn();
}

const _AI_QUOTE_SYSTEM = `
Tu es un assistant commercial de Vector France S.A.S. Tu rédiges des emails internes de demande de devis à destination de l'assistant commercial.
À partir de l'email client fourni, rédige directement l'email de demande de devis à envoyer en interne. Inclus le nom du client, son email, et les produits/options souhaités tels que tu les comprends.
Rédige uniquement le corps de l'email, sans objet ni en-tête technique.

Le catalogue Vector inclut entre autres (il peut y en avoir d'autres) :
Produits : CANalyzer (canalyzer,55100), CANoe (canoe,55000), CANdb++ (candb,56100), CANape (canape,57100), vTESTstudio (vtestudio,vtest), VectorCAST (vectorcast), CANstress (canstress), MICROSAR (microsar,autosar), VN-Interface (vn1610,vn1630,vn1640,vn5610,vn5620,vn7610,vn7640)
Options : Licence perpétuelle (perpetual), Maintenance (ma-,maintenance,update), ELA (ela,enterprise licensing), Network License (network license,licence reseau), Device License (device license,poste), Formation (formation,training), Renouvellement maintenance (renouvellement,renewal)
`;

async function aiQuoteDraft() {
  await deleteQuoteAndReset(async () => {
    if (!window._Anthropic)    { toast('SDK Anthropic non chargé — attendez quelques secondes.'); return; }
    if (!window._anthropicKey) { toast('Clé Anthropic introuvable (env.txt).'); return; }
    if (!CURRENT || !CURRENT.body) { toast('Corps du mail vide — impossible d\'analyser.'); return; }

    await withBusy('Analyse IA en cours…', async () => {
      try {
        const client = new window._Anthropic({ apiKey: window._anthropicKey, dangerouslyAllowBrowser: true });
        const userContent = `Client : ${fullName(CURRENT) || CURRENT.email}\nE-mail : ${CURRENT.email}\n\n${CURRENT.body}`;
        const request = { model: 'claude-haiku-4-5-20251001', max_tokens: 1024, system: _AI_QUOTE_SYSTEM, messages: [{ role: 'user', content: userContent }] };
        console.log('[IA Quote] request:', request);

        const msg = await client.messages.create(request);
        console.log('[IA Quote] response:', msg);

        const draft = msg.content[0]?.text || '';

        const box = document.getElementById('quoteDraftBox');
        if (box) { box.value = draft; scheduleQuoteDraftSave(); }
        toast('✦ Template IA appliqué.');
      } catch (e) { toast('Erreur IA : ' + e.message); }
    });
  });
}

function resetQuoteDraft() {
  deleteQuoteAndReset(() => {
    const box = document.getElementById('quoteDraftBox');
    if (!box || !CURRENT) return;
    box.value = defaultQuoteDraft(CURRENT);
    scheduleQuoteDraftSave();
  });
}

async function searchQuote() {
  await withBusy('Recherche devis…', async () => {
    try {
      await tryMatchQuote();
      if (!CURRENT.hasQuote) toast('Aucun devis trouvé pour ce lead.');
    } catch (e) { toast('Erreur: ' + e.message); }
  });
}

async function tryMatchQuote() {
  if (!CURRENT || CURRENT.hasQuote) return;
  const body = document.getElementById('quoteBody');
  try {
    const res = await apiPdf('/api/match-quote?id=' + encodeURIComponent(CURRENT.id), { method: 'POST' });
    if (res.matched) {
      CURRENT = await apiPdf('/api/lead?id=' + encodeURIComponent(CURRENT.id));
      renderDetail();
      loadTemplate();
      await loadLeads();
      toast('Devis associé automatiquement.');
    } else {
      renderDetail();
      if (!CURRENT.replyDraft) loadTemplate();
    }
  } catch (e) {
    renderDetail();
    if (!CURRENT.replyDraft) loadTemplate();
  }
}

let _quoteDraftTimer = null;
function scheduleQuoteDraftSave() {
  clearTimeout(_quoteDraftTimer);
  _quoteDraftTimer = setTimeout(quoteDraftAutoSave, 800);
}

async function quoteDraftAutoSave() {
  if (!CURRENT) return;
  const draft = document.getElementById('quoteDraftBox')?.value;
  if (draft === undefined) return;
  try {
    await apiPdf('/api/lead?id=' + encodeURIComponent(CURRENT.id),
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ quoteDraft: draft }) });
    CURRENT.quoteDraft = draft;
    toast('Brouillon devis sauvegardé.');
  } catch (e) { toast('Erreur sauvegarde devis : ' + e.message); }
}

async function generateQuote() {
  const recipient = window._devisCreateurMail || '(destinataire non configuré)';
  if (!confirm('Envoyer la demande de devis à ' + recipient + ' ?')) return;
  await withBusy('Génération devis…', async () => {
    await withOutlook(async () => {
      const draft = document.getElementById('quoteDraftBox')?.value || '';
      try {
        const res = await apiPdf('/api/generate-quote?id=' + encodeURIComponent(CURRENT.id), {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ quoteDraft: draft })
        });
        CURRENT.status = res.status;
        const badge = document.getElementById('statusBadge');
        if (badge) { badge.className = 'badge clickable ' + statusClass(res.status); badge.textContent = (STATUS_LABELS[res.status] || res.status) + ' ✎'; }
        await loadLeads();
        toast('Demande de devis émise.');
      } catch (e) { toast('Erreur: ' + e.message); }
    });
  });
}

async function previewQuote() {
  await withBusy('Ouverture brouillon…', async () => {
    await withOutlook(async () => {
      const draft = document.getElementById('quoteDraftBox')?.value || '';
      // Display() bloque le thread STA → fire-and-forget
      fetch('/api/generate-quote?id=' + encodeURIComponent(CURRENT.id) + '&preview=1', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ quoteDraft: draft })
      }).catch(() => {});
      toast('👁 Brouillon ouvert dans Outlook.');
    });
  });
}



function quoteDragOver(e) {
  e.preventDefault();
  const dz = document.getElementById('quoteDrop');
  if (dz) { dz.style.borderColor = 'var(--accent)'; dz.style.background = 'rgba(79,156,249,.08)'; dz.style.color = 'var(--txt)'; }
}

function quoteDragLeave(e) {
  const dz = document.getElementById('quoteDrop');
  if (dz) { dz.style.borderColor = 'var(--line)'; dz.style.background = ''; dz.style.color = 'var(--muted)'; }
}

async function quoteUploadFile(file) {
  if (!file) return;
  if (!file.name.toLowerCase().endsWith('.pdf')) { toast('Seuls les fichiers PDF sont acceptés.'); return; }
  if (CURRENT.hasQuote && !confirm('Un devis est déjà enregistré pour ce lead.\nIl sera remplacé. Continuer ?')) return;
  await withBusy('Upload en cours…', async () => {
    try {
      const b64 = await new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = ev => resolve(ev.target.result.split(',')[1]);
        reader.onerror = reject;
        reader.readAsDataURL(file);
      });
      await apiPdf('/api/upload-quote?id=' + encodeURIComponent(CURRENT.id) + '&replace=' + (CURRENT.hasQuote ? '1' : '0'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename: file.name, data: b64 })
      });
      CURRENT = await apiPdf('/api/lead?id=' + encodeURIComponent(CURRENT.id));
      renderDetail(); render();
      loadTemplate();
      await loadLeads();
      toast('Devis ajouté avec succès.');
    } catch (ex) { toast('Erreur upload: ' + ex.message); }
  });
}

function quoteFileSelected(input) { const file = input.files[0]; input.value = ''; quoteUploadFile(file); }
async function quoteDrop(e) { e.preventDefault(); quoteDragLeave(e); quoteUploadFile(e.dataTransfer.files[0]); }
