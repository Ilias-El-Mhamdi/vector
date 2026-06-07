function renderLeadItem(l, emailCount) {
  const items = l.items && l.items.length ? l.items : null;
  const chips = items
    ? items.map(i => {
        const qty      = (i.quantite || 1) > 1 ? ` <strong>×${i.quantite}</strong>` : '';
        const optChips = (i.options || []).map(o => renderChip(o, 'opt')).join('');
        return `<span class="chip prod">${esc(i.produit)}${qty}</span>${optChips}`;
      }).join('')
    : (l.products || []).map(p => renderChip(p.name || p, 'prod')).join('')
    + (l.options  || []).map(o => renderChip(o, 'opt')).join('');

  const cnt      = emailCount[l.email] || 1;
  const msgBadge = cnt > 1
    ? `<span title="${cnt} messages reçus de ce contact" style="display:inline-flex;align-items:center;gap:3px;background:rgba(210,153,34,.18);color:var(--orange);border:1px solid rgba(210,153,34,.35);border-radius:20px;font-size:11px;font-weight:600;padding:1px 7px;white-space:nowrap">⚠ ${cnt} msg</span>`
    : '';

  return `
    <div class="top">
      <span class="name">${esc(fullName(l))}</span>
      ${renderBadge(l.status)}
    </div>
    <div style="display:flex;align-items:center;gap:6px;margin-top:3px">
      <span style="color:var(--muted);font-size:12px;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(l.email)} ${l.hasQuote ? '📎' : ''}</span>
      ${msgBadge}
    </div>
    <div style="display:flex;align-items:center;justify-content:space-between;margin-top:5px">
      <div class="chips">${chips}</div>
      ${l.date ? `<span style="color:var(--muted);font-size:11px;white-space:nowrap;margin-left:8px">${esc(l.date)}</span>` : ''}
    </div>`;
}
