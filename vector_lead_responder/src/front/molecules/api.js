function esc(s) {
  return (s == null ? '' : String(s))
    .replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
}

const PDF_BASE = 'http://localhost:8732';

async function api(path, opts) {
  const r = await fetch(path, opts);
  if (!r.ok) { const txt = await r.text(); throw new Error(txt || r.status); }
  const ct = r.headers.get('content-type') || '';
  return ct.includes('json') ? r.json() : r.text();
}

async function apiPdf(path, opts) {
  const r = await fetch(PDF_BASE + path, opts);
  if (!r.ok) { const txt = await r.text(); throw new Error(txt || r.status); }
  const ct = r.headers.get('content-type') || '';
  return ct.includes('json') ? r.json() : r.text();
}

function fullName(l) {
  return [l.prenom, l.nom].filter(Boolean).join(' ').trim() || l.email;
}
