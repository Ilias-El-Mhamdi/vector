function renderDetail() {
  const l = CURRENT;
  const d = document.getElementById('detail');
  if (!l) { d.innerHTML = '<div class="empty">Sélectionnez un lead.</div>'; return; }

  const prods = (l.products || []).map(p => renderChip(p.name || p, 'prod')).join('') || '<span class="sub">—</span>';
  const opts  = (l.options  || []).map(o => renderChip(o, 'opt')).join('')  || '<span class="sub">—</span>';

  const statusOptions = Object.keys(STATUS_LABELS).map(s =>
    `<option value="${s}" ${l.status === s ? 'selected' : ''}>${STATUS_LABELS[s]}</option>`
  ).join('');

  d.innerHTML = `
    <div class="dhead">
      <div class="row1">
        <h2>${esc(fullName(l))}</h2>
        <span id="statusBadge" class="badge clickable ${statusClass(l.status)}" onclick="openStatusEdit()" title="Cliquer pour modifier">
          ${STATUS_LABELS[l.status] || l.status} ✎
        </span>
        <select id="statusSel" onchange="changeStatus(this.value)" style="display:none;font-size:11px;padding:2px 6px;border-radius:20px">
          ${statusOptions}
        </select>
      </div>
      <div class="mail" onclick="copyEmail('${esc(l.email)}')" title="Cliquer pour copier" style="cursor:pointer;display:inline-flex;align-items:center;gap:6px">
        ✉️ ${esc(l.email)} <span style="opacity:.5;font-size:12px">⧉</span>
      </div>
      <div class="meta">${prods} ${opts}</div>
      <div class="toolbar">
        <button class="btn ghost" onclick="openFolder()">📂 Dossier</button>
      </div>
    </div>

    <div class="dgrid">
      ${renderMailCard(l)}
      ${renderQuoteCard(l)}
      ${renderReplyCard(l)}
    </div>`;
}

function openStatusEdit() {
  document.getElementById('statusBadge').style.display = 'none';
  const sel = document.getElementById('statusSel');
  sel.style.display = 'inline-block';
  sel.focus();
  sel.onblur = () => { sel.style.display = 'none'; document.getElementById('statusBadge').style.display = ''; };
}

async function changeStatus(s) {
  try {
    await api('/api/lead?id=' + encodeURIComponent(CURRENT.id),
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ status: s }) });
    CURRENT.status = s;
    const badge = document.getElementById('statusBadge');
    if (badge) { badge.className = 'badge clickable ' + statusClass(s); badge.textContent = (STATUS_LABELS[s] || s) + ' ✎'; badge.style.display = ''; }
    document.getElementById('statusSel').style.display = 'none';
    await loadLeads();
    toast('Statut: ' + (STATUS_LABELS[s] || s));
  } catch (e) { toast('Erreur: ' + e.message); }
}

async function refreshLead() {
  await withBusy('Rechargement Outlook…', async () => {
    await withOutlook(async () => {
      try {
        CURRENT = await api('/api/lead/refresh?id=' + encodeURIComponent(CURRENT.id), { method: 'POST' });
        renderDetail(); render();
        toast('Mail rechargé depuis Outlook.');
      } catch (e) { toast('Erreur: ' + e.message); }
    });
  });
}

async function openFolder() {
  try {
    await api('/api/open-folder?id=' + encodeURIComponent(CURRENT.id), { method: 'POST' });
    toast('📂 Dossier ouvert dans l\'explorateur.');
  } catch (e) { toast('Erreur: ' + e.message); }
}

async function openMailOutlook() {
  await withBusy('Ouverture dans Outlook…', async () => {
    await withOutlook(async () => {
      try { await api('/api/open-mail?id=' + encodeURIComponent(CURRENT.id), { method: 'POST' }); }
      catch (e) { toast('Erreur Outlook: ' + e.message); }
    });
  });
}

function copyEmail(email) {
  navigator.clipboard.writeText(email)
    .then(() => toast('Email copié : ' + email))
    .catch(() => toast('Erreur copie'));
}
