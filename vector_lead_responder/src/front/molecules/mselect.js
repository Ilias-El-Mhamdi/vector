const ALL_STATUSES = [
  { v: 'devis non demande', l: 'Devis non demandé' },
  { v: 'devis demande',     l: 'Devis demandé' },
  { v: 'devis recu',        l: 'Devis reçu' },
  { v: 'traite',            l: 'Traité' },
  { v: 'ignore',            l: 'Ignoré' },
];

function buildPanel(panelId, items, defaultChecked) {
  document.getElementById(panelId).innerHTML = items.map(({ v, l }) => `
    <label>
      <input type="checkbox" value="${esc(v)}" ${defaultChecked(v) ? 'checked' : ''} onchange="onFilterChange('${panelId}')">
      ${esc(l)}
    </label>`).join('');
}

function toggleMSelect(id) {
  const panel  = document.getElementById(id + '-panel');
  const isOpen = panel.classList.contains('open');
  document.querySelectorAll('.mselect-panel.open').forEach(p => p.classList.remove('open'));
  if (!isOpen) panel.classList.add('open');
}

function getChecked(panelId) {
  return [...document.querySelectorAll('#' + panelId + '-panel input:checked')].map(c => c.value);
}

function updateBtnLabel(msId, allLabel) {
  const checked = getChecked(msId);
  const btn     = document.querySelector('#' + msId + ' .mselect-btn .label');
  btn.textContent = checked.length === 0 ? allLabel
    : checked.length === 1 ? (document.querySelector('#' + msId + '-panel input:checked')?.parentElement?.textContent?.trim() || checked[0])
    : checked.length + ' sélectionnés';
}

function onFilterChange(panelId) {
  const msId   = panelId.replace('-panel', '');
  const labels = { 'ms-product': 'Tous produits', 'ms-status': 'Sauf ignorés', 'ms-option': 'Toutes options', 'ms-quote': 'Tous' };
  updateBtnLabel(msId, labels[msId] || 'Tous');
  render();
}
