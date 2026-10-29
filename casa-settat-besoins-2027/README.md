# Besoins des agences — DR Casablanca-Settat

Application en français pour la collecte des besoins d’investissement 2027 à partir du fichier `Copy of bugget.xlsx`.

## Parcours

- Le participant indique le nom complet de son agence, puis renseigne uniquement les quantités et les commentaires.
- Les 175 équipements et leurs rubriques sont conservés : 12 articles dans `Sheet1`, 163 dans `Sheet2`.
- Le brouillon reste dans le navigateur. Le bouton de confirmation enregistre les demandes dans une base partagée.
- Le formulaire comporte deux étapes. « Suivant » termine la feuille Informatique et affiche Équipements & mobilier. « Précédent » et les onglets permettent de revenir et de modifier les saisies.
- Une demande non envoyée ou des modifications depuis le dernier envoi déclenchent un avertissement en français et en arabe avant de suivre un lien qui quitte le formulaire. La fermeture, le rechargement et le retour du navigateur déclenchent son avertissement natif, dont le texte dépend du navigateur. Une version envoyée sans nouvelle modification ne déclenche pas d’avertissement.
- Depuis le même navigateur, un nouvel envoi pour une agence remplace la demande précédente. Un autre navigateur ne peut pas écraser la demande de cette agence.
- `/gestion` est réservé au coordinateur. Le mot de passe est défini exclusivement dans les secrets du serveur.
- Le coordinateur peut supprimer la demande d’une agence depuis sa ligne après confirmation. La demande et ses quantités sont retirées des prochains exports. Une demande modifiée depuis l’ouverture de la confirmation ne peut pas être supprimée sans actualiser la liste.
- Le téléchargement consolide toutes les agences ou une agence sélectionnée. Les quantités sont additionnées et les commentaires suivent le format `Agence Settat : 3 — précisions`.

## Modèle Excel

Le modèle OOXML d’origine est inclus dans `lib/excel-template.json`. L’export conserve exactement deux feuilles et ne remplit que :

| Feuille | Quantité | Commentaire et autres précisions |
| --- | --- | --- |
| Sheet1 | H10:H21 | J10:J21 |
| Sheet2 | F10:F172 | I10:I172 |

Les autres cellules et tous les autres composants du classeur sont conservés. Les commentaires sont enregistrés comme texte, même s’ils commencent par un signe de formule.

Les quantités acceptent deux décimales au maximum et doivent être comprises entre 0,01 et 100 000. Les commentaires sont limités à 1 500 caractères. En cas de dépassement de la limite Excel de 32 767 caractères par cellule, l’export consolidé signale l’article concerné et propose l’export par agence.

## Développement

Projet Vinext / React sur Cloudflare Workers, avec Cloudflare D1. Installer les dépendances à partir du fichier de verrouillage, configurer les variables de `.env.example` dans un fichier local `.dev.vars` ignoré par Git, générer les migrations avec `npm run db:generate`, puis lancer `npm run dev`.

Commandes de vérification : `node scripts/test-core.mjs`, `node scripts/test-form-state.mjs`, `node --experimental-vm-modules scripts/test-api.mjs`, `npx tsc --noEmit`, `npm run build`.

La base et les secrets sont nécessaires au fonctionnement partagé. GitHub Pages seul ne fournit pas le serveur ni la base de collecte. Le dépôt conserve le code, tandis que l’application publiée héberge le formulaire et son service d’enregistrement.

## Interface GitHub Pages

`node scripts/build-github-pages.mjs` produit une interface statique complète dans `outputs/github-pages/`. Publier le contenu de ce dossier sous `/docs` à la racine du dépôt, puis activer GitHub Pages sur la branche `casa-settat-besoins-2027`, dossier `/docs`. L’entrée `besoin2027/` contient le formulaire et la gestion, accessible avec `?page=gestion`.

Le formulaire, les liens, la connexion du coordinateur et les téléchargements restent sur le domaine GitHub Pages. Le service de données conserve la même base. `PUBLIC_WEB_ORIGIN=https://univcours.github.io` autorise seulement l’origine de ce compte. Le client statique utilise des sessions signées, sans cookies tiers. La session du coordinateur est conservée dans la session de l’onglet. Le mot de passe et la clé de signature restent exclusivement sur le serveur.

Ne jamais committer `.dev.vars`, les mots de passe, les sessions ou les réponses des agences.
## Comptage mensuel des envois

Le formulaire « Comptage des envois » reprend les 16 colonnes de la photo : date, fréquence (1/5 à 5/5) et 14 rubriques. Le mois de novembre 2026 reprend les 19 dates de la photo. Pour les autres mois, les dates proposées vont du lundi au vendredi ; une date supplémentaire du mois peut être ajoutée.

L’agence saisit son nom, sélectionne obligatoirement une **tournée numérotée de 1 à 10** et choisit un mois, puis remplit le canevas par journée ou dans le tableau complet. Chaque couple agence–tournée–mois possède une demande distincte ; le numéro de tournée fait partie de la clé d'agence transmise à l'API existante pour éviter de modifier ou d'écraser le comptage d'une autre tournée. Une case vide reste non renseignée ; zéro reste un zéro explicite. Les nombres d’envois sont des entiers. Chaque journée renseignée demande une fréquence. Les brouillons sont conservés séparément par agence et par mois sur l’appareil. L’envoi demande une confirmation, puis un accusé du serveur. Le même navigateur peut remplacer son comptage mensuel ; un autre navigateur ne peut pas écraser la même agence et le même mois.

Le coordinateur retrouve le module dans le même espace protégé, avec filtre mensuel, recherche par agence et détails quotidiens. L’export Excel conserve les en-têtes groupés, la grille et les formules de totaux du canevas. Un export de toutes les tournées contient une feuille par couple agence–tournée. Le modèle Excel indique « Tournée N°: numéro » sur la deuxième ligne, dans le service d'export mis à jour. La fréquence n’est jamais additionnée. Supprimer un comptage retire uniquement ce mois pour cette agence et conserve les autres mois et les besoins 2027.

Sur GitHub Pages : formulaire `?page=comptage`, gestion `?page=gestion-comptage`. Sur le Site : `/comptage`, gestion `/gestion?section=comptage`.

Vérification du module : `node scripts/test-comptage.mjs` et `node --experimental-vm-modules scripts/test-api.mjs`. Migration ajoutée : `drizzle/0001_funny_doctor_strange.sql`.
