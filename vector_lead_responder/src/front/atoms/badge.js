const STATUS_LABELS = {
  'ignore':            'Ignoré',
  'devis non demande': 'Devis non demandé',
  'devis demande':     'Devis demandé',
  'devis recu':        'Devis reçu',
  'traite':            'Traité',
};

function statusClass(s) {
  return 'st-' + (s || '').replace(/\s/g, '');
}

function renderBadge(status) {
  return `<span class="badge ${statusClass(status)}">${STATUS_LABELS[status] || status}</span>`;
}

function renderChip(text, type = '') {
  return `<span class="chip ${type}">${esc(text)}</span>`;
}
