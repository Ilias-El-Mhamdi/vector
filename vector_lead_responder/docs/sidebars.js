/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  mainSidebar: [
    'intro',
    {
      type: 'category',
      label: 'Démarrage',
      collapsed: false,
      items: ['demarrage/installation', 'demarrage/configuration'],
    },
    {
      type: 'category',
      label: 'Architecture',
      items: ['architecture/vue-ensemble', 'architecture/backend', 'architecture/frontend'],
    },
    {
      type: 'category',
      label: 'Référence API',
      items: ['api/routes'],
    },
    {
      type: 'category',
      label: 'Données',
      items: ['donnees/schema-lead', 'donnees/catalogue'],
    },
    {
      type: 'category',
      label: 'Guides',
      items: ['guides/ajouter-route', 'guides/ajouter-composant', 'guides/machine-etats'],
    },
    'deploiement',
  ],
};

module.exports = sidebars;
