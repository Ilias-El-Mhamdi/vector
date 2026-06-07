function renderReplyCard(l) {
  return `
    <div class="card" style="grid-column:1 / -1">
      <h3 style="display:flex;align-items:center;justify-content:space-between">📝 Mail de réponse à envoyer<span style="display:flex;gap:4px"><button class="btn ghost" style="font-size:11px;padding:2px 8px" onclick="loadTemplate()" title="Réappliquer le template">↺ Template</button><button class="btn ghost" style="font-size:11px;padding:2px 8px" onclick="aiReplyDraft()" title="Générer avec l'IA">✦ IA Template</button></span></h3>
      <div class="body">
        <textarea id="replyBox" class="reply" placeholder="Rédigez votre réponse..." oninput="scheduleAutoSave()">${esc(l.replyDraft || '')}</textarea>
        <div class="toolbar">
          <div class="spacer" style="flex:1"></div>
          <button class="btn ghost" onclick="sendLead(false)">👁 Voir dans Outlook</button>
          <button class="btn green"  onclick="sendLead(true)">📤 Envoyer</button>
        </div>
      </div>
    </div>`;
}

function renderMailCard(l) {
  const bodyHtml = l.body
    ? `<div class="mailbody">${esc(l.body)}</div>`
    : `<div class="noquote" style="padding:20px">
        Corps vide (mail HTML ou non téléchargé depuis Exchange).<br><br>
        <button class="btn ghost" onclick="refreshLead()">🔄 Re-lire depuis Outlook</button>
      </div>`;

  return `
    <div class="card">
      <h3>📥 Mail reçu — ${esc(l.subject || '(sans objet)')}</h3>
      <div class="body">
        <p class="sub">${esc(l.date || '')}</p>
        ${bodyHtml}
      </div>
    </div>`;
}

const _AI_REPLY_SYSTEM = `Tu es un assistant commercial de Vector France S.A.S. Tu rédiges des réponses aux emails clients concernant des demandes de devis pour des logiciels embarqués (CANoe, CANape, etc.).

Tu reçois deux informations :
1. Le mail original du client (sa demande)
2. Le brouillon de demande de devis interne : c'est le mail qui a été envoyé en interne pour faire établir le devis — il contient les produits, quantités et options retenus pour ce client. Ce devis sera joint en pièce jointe à l'email de réponse que tu rédiges.

Règles strictes :
- Rédige UNIQUEMENT le contenu central de l'email : ni formule d'ouverture, ni signature, ni formule de politesse finale
- Ton cordial et professionnel, phrases courtes
- Mentionne explicitement que le devis est joint à cet email
- Base-toi sur les produits et options du brouillon de devis pour personnaliser la réponse
- Inclus obligatoirement cette phrase exacte dans le corps : "Veuillez envoyer votre bon de commande à adv@fr.vector.com en précisant votre numéro de devis" et Si un numéro de devis (quoteId) est fourni ajoute " : <quoteId>"`;

function getReplySignature() {
  return window._replySignature || 'Bien cordialement,\nVector France S.A.S';
}

async function aiReplyDraft() {
  if (!window._Anthropic)    { toast('SDK Anthropic non chargé — attendez quelques secondes.'); return; }
  if (!window._anthropicKey) { toast('Clé Anthropic introuvable (env.txt).'); return; }
  if (!CURRENT || !CURRENT.body) { toast('Corps du mail vide — impossible de générer une réponse.'); return; }

  await withBusy('Génération réponse IA…', async () => {
    try {
      const client = new window._Anthropic({ apiKey: window._anthropicKey, dangerouslyAllowBrowser: true });
      const quoteDraft = document.getElementById('quoteDraftBox')?.value || CURRENT.quoteDraft || '';
      const quoteId    = CURRENT.quoteId || '';
      const quoteIdLine = quoteId ? `\n=== Numéro de devis (quoteId) ===\n${quoteId}` : '';
      const userContent = `=== Mail du client ===\n${CURRENT.body}\n\n=== Brouillon de demande de devis interne ===\n${quoteDraft || '(non disponible)'}${quoteIdLine}`;
      const request = {
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 400,
        system: _AI_REPLY_SYSTEM,
        messages: [{ role: 'user', content: userContent }]
      };
      console.log('[IA Reply] request:', request);

      const msg = await client.messages.create(request);
      console.log('[IA Reply] response:', msg);

      const opening = CURRENT.prenom ? `Bonjour ${CURRENT.prenom},` : 'Madame, Monsieur,';
      let aiBody = (msg.content[0]?.text || '').trim();
      // Garantit la présence de la phrase bon de commande si quoteId connu et absente du texte IA
      if (quoteId && !aiBody.includes('bon de commande')) {
        aiBody += `\n\nVeuillez envoyer votre bon de commande à adv@fr.vector.com en précisant votre numéro de devis : ${quoteId}`;
      }
      const text = opening + '\n\n' + aiBody + '\n\n' + getReplySignature();
      const box  = document.getElementById('replyBox');
      if (box) { box.value = text; scheduleAutoSave(); }
      toast('✦ Réponse IA générée.');
    } catch (e) { toast('Erreur IA : ' + e.message); }
  });
}

function loadTemplate() {
  let tpl = CATALOG.replyTemplate || '';
  const quoteId = CURRENT.quoteId || '';
  tpl = tpl
    .replace(/{{prenom}}/g,        CURRENT.prenom || 'Madame, Monsieur')
    .replace(/{{produits}}/g,       (CURRENT.products || []).map(p => p.name || p).join(', '))
    .replace(/{{options_phrase}}/g, (CURRENT.options && CURRENT.options.length)
      ? ' (options : ' + CURRENT.options.join(', ') + ')' : '')
    .replace(/{{quoteId}}/g,   quoteId ? ` : ${quoteId} ` : ' ')
    .replace(/{{signature}}/g, getReplySignature());
  const box = document.getElementById('replyBox');
  if (box) { box.value = tpl; }
}

let _autoSaveTimer = null;
function scheduleAutoSave() {
  clearTimeout(_autoSaveTimer);
  _autoSaveTimer = setTimeout(autoSave, 800);
}

async function autoSave() {
  if (!CURRENT) return;
  const reply = document.getElementById('replyBox')?.value;
  if (reply === undefined) return;
  try {
    await api('/api/lead?id=' + encodeURIComponent(CURRENT.id),
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ replyDraft: reply }) });
    CURRENT.replyDraft = reply;
    toast('Brouillon réponse sauvegardé.');
  } catch (e) { toast('Erreur sauvegarde réponse : ' + e.message); }
}

async function sendLead(direct) {
  if (direct && !confirm('Envoyer le mail avec le devis en pièce jointe ?')) return;
  await withBusy(direct ? 'Envoi en cours…' : 'Ouverture dans Outlook…', async () => {
    await withOutlook(async () => {
      if (!direct) {
        // Display() bloque le thread STA → connexion TCP coupée → fire-and-forget
        fetch('/api/send?id=' + encodeURIComponent(CURRENT.id) + '&direct=0', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ replyDraft: document.getElementById('replyBox').value })
        }).catch(() => {});
        toast('👁 Mail ouvert dans Outlook.');
        return;
      }
      try {
        const res = await api(
          '/api/send?id=' + encodeURIComponent(CURRENT.id) + '&direct=1',
          { method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ replyDraft: document.getElementById('replyBox').value }) }
        );
        CURRENT.status = res.status;
        await loadLeads();
        renderDetail();
        toast('📤 Mail envoyé. Lead passé en « Traité ».');
      } catch (e) { toast('Erreur envoi : ' + e.message); }
    });
  });
}
