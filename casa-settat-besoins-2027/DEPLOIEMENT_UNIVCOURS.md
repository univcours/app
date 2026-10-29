# Migration de la plateforme vers le compte GitHub univcours

## Cible : aucune modification des liens utilisateur

Le code du site, le code de son API, les migrations et le déploiement sont gérés dans le dépôt GitHub **univcours/app**.

Les adresses publiques de l'interface doivent rester **identiques** :
- Formulaire : https://univcours.github.io/app/besoin2027/?page=comptage
- Administration : https://univcours.github.io/app/besoin2027/?page=gestion-comptage
- Contrôle des codes-barres : https://univcours.github.io/app/besoin2027/controle.html
- Ancien lien `?page=gestion` : maintenir son comportement de redirection vers l'administration Comptage

Les quatre opérations de contrôle restent **Bouclage AM**, **Notification des envois enregistrés**, **Notification des envois recommandés**, **HDG**. Le fichier importé contient **CAB** et **NomAgence**, les correspondances confirmées sont réutilisées, et les CAB sont réservés à leur agence officielle.

## Limite technique importante

**GitHub Pages ne peut pas exécuter de serveur ou de base de données partagée.** Il publie la partie statique uniquement. La solution séparée préparée ici utilise **Cloudflare Workers + D1** comme service d'exécution, **entièrement versionné et déployé depuis GitHub Actions**. Le compte Cloudflare appartient au propriétaire de la plateforme, et non à ChatGPT Sites.

L'ancien nom de domaine `besoin2027.hamidtawfiq2.chatgpt.site` ne peut pas être transféré sur GitHub : il appartient à la plateforme ChatGPT Sites. En revanche, les liens utilisateur **GitHub Pages** ci-dessus ne changent pas. Il faut attendre la migration des données avant de déconnecter l'ancienne API.

## Préparations déjà disponibles dans univcours/app

- `worker/standalone-api.ts` — API autonome réutilisant les routes existantes (/api/session, /api/comptage/*, /api/admin/*, /api/controle/*).
- `worker/migrations/0000_*.sql` à `0004_*.sql` — schéma des deux anciens modules, des codes-barres, des consultations et des associations.
- `scripts/generate-github-worker-config.mjs` — génère la configuration Wrangler depuis les variables GitHub ; **aucun identifiant secret n'est commité**.
- `scripts/verify-univcours-api.mjs` — vérifie `/api/controle/health`.
- `.github/workflows/deploy-comptage-api.yml` sur la branche **master** — déploiement manuel depuis le menu Actions du dépôt.
- `docs/besoin2027/api-config.js` — seul réglage de la destination API sur les pages déjà publiées. Par sécurité, **il utilise encore l'ancien serveur**. La page de comptage et celle de contrôle chargent toutes deux ce réglage.

## Configuration requise une seule fois (par le propriétaire des comptes)

1. Dans **son compte Cloudflare**, créer une base **D1 nommée `univcours-comptage`** (base nouvelle tant que les données de l'ancienne plateforme ne sont pas disponibles), relever son identifiant UUID. Autoriser un jeton API Cloudflare limité au compte et aux droits nécessaires pour déployer un Worker, affecter des secrets et migrer D1.
2. Dans GitHub `univcours/app`, ouvrir **Settings → Secrets and variables → Actions** et créer ces **Secrets** (ne jamais les coller dans le dépôt ou le chat) :
   - `CLOUDFLARE_API_TOKEN`
   - `CLOUDFLARE_ACCOUNT_ID`
   - `UNIVCOURS_ADMIN_PASSWORD` (mot de passe coordinateur, à choisir de manière forte)
   - `UNIVCOURS_SESSION_SECRET` (au moins 32 caractères ; choisir un secret fort et conserver la même clé si la migration des sessions est voulue)
3. Créer la variable GitHub **`UNIVCOURS_D1_DATABASE_ID`** avec l'UUID D1, puis après la première publication la variable **`UNIVCOURS_API_URL`** avec l'adresse HTTPS `*.workers.dev` réellement fournie par Cloudflare.
4. Dans GitHub **Actions → Deploy univcours agency API (manual) → Run workflow**. Le workflow crée seulement la **nouvelle API** et applique ses migrations dans la D1 choisie. Il ne modifie pas encore les pages publiques ou l'ancien serveur.
5. Vérifier `GET ${UNIVCOURS_API_URL}/api/controle/health` → HTTP 200, `{"ready":true}` ; tester l'authentification du coordinateur, un import Excel réduit, les quatre opérations, les associations d'agences, une validation OK et une anomalie.

## Étape **OBLIGATOIRE** avant de basculer le trafic

L'ancien Site ChatGPT conserve possiblement des données importantes : Comptage mensuel, ancienne application Besoins 2027, sessions de participation et éventuellement d'autres états. **Ces données ne sont pas automatiquement exportables depuis GitHub, et l'ancien serveur ne fournit pas de migration publique vérifiée.** Il faut un export **autorisé depuis l'ancien projet Sites / sa base D1**, restaurer les enregistrements requis dans la nouvelle D1 et effectuer un rapprochement des volumes et des clés uniques par table. Ne jamais écraser ou réinitialiser les anciennes données.

Attention : les sessions signées avec l'ancien `SESSION_SECRET` devront être préservées si le secret est disponible ; sinon prévoir une réactivation contrôlée des agences en évitant les doublons. Le transfert de simples fichiers CAB ne suffit pas pour conserver le suivi et les données mensuelles.

**Seulement après** sauvegarde, import des données, tests multi-navigateurs et accord du propriétaire, remplacer la valeur de `window.__UNIVCOURS_API_BASE__` dans **les deux fichiers** `docs/besoin2027/api-config.js` et `casa-settat-besoins-2027/public/api-config.js` par l'URL HTTPS du nouveau Worker, puis publier le commit GitHub Pages. Aucune URL des pages utilisateurs n'est à modifier. Ne jamais basculer prématurément vers une base vide.

## Sécurité

Les dossiers `docs` et tout le dépôt public ne doivent jamais stocker les CAB réels, mots de passe, sessions ou extraits D1. Les données d'agence restent dans la base protégée. La seule sélection du nom d'agence **n'authentifie pas** l'agent ; un contrôle d'accès par agence est recommandé avant la mise en service réelle.

## Statut actuel

- Code et automatisation sur GitHub : **préparés**.
- Publication de la nouvelle API sur Cloudflare : **non exécutée** (identifiants de compte manquants).
- Migration des anciennes données : **non exécutée** (ancien projet Sites non connecté).
- Basculement de l'API GitHub Pages : **non exécuté volontairement**, pour préserver le service et les liens.
