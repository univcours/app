# Déploiement du contrôle des codes-barres sur le Site existant

## Périmètre exact

**Site ChatGPT Sites existant** : `https://besoin2027.hamidtawfiq2.chatgpt.site`

**Interface statique déjà publiée** : `https://univcours.github.io/app/besoin2027/controle.html`

**Source** : dépôt `univcours/app`, branche `casa-settat-besoins-2027`, dossier `casa-settat-besoins-2027`.

**État** : l'interface GitHub Pages est publiée, mais le Site existant n'expose pas encore les routes `/api/controle/*` ni `/api/admin/controle/*`. Une erreur HTTP 404 `Ressource introuvable` en découle. La mise à jour de GitHub Pages ne publie pas le backend du Site ChatGPT. Il faut ouvrir **ce Site existant dans ChatGPT Sites via Work/Codex** et y publier une nouvelle version. Ne pas créer un deuxième Site ni changer son URL.

## Opérations de déploiement

1. Ouvrir le Site existant depuis le compte qui le possède, inspecter le code réellement déployé et vérifier qu'il utilise le service d'enregistrement existant. Effectuer une **sauvegarde** de la base actuelle ou une capture des tables/données essentielles, surtout les données de `Besoins 2027` et du comptage mensuel. Ne pas effacer ou recréer la base.
2. Synchroniser le **serveur** depuis les sources GitHub : `app/api/[...path]/route.ts`, `lib/controle-api.ts`, `lib/controle.mjs`, `lib/count-agencies.mjs`, `lib/agency-match.mjs`, `lib/security.ts`, `lib/validation.mjs` et `db/schema.ts`. Respecter le chemin, les imports et le runtime actuels de ChatGPT Sites. Vérifier que les anciennes routes `/api/session`, `/api/comptage/*` et `/api/admin/login` continuent de fonctionner.
3. Appliquer à la base **existante**, de façon incrémentale, les migrations suivantes, dans cet ordre : `drizzle/0002_controle_codes.sql` (table `controle_codes`), `drizzle/0003_controle_acces.sql` (table `controle_acces`) et `drizzle/0004_controle_agency_aliases.sql` (table `controle_agency_aliases`). Ces scripts sont additifs et utilisent `CREATE TABLE IF NOT EXISTS`. Vérifier et inscrire les migrations dans le système de suivi réellement utilisé par le Site. **Aucun DROP, TRUNCATE, DELETE ni reset de la base existante.**
4. Prévisualiser, lancer les tests disponibles, conserver les secrets serveur existants (`ADMIN_PASSWORD`, `SESSION_SECRET`) et l'origine GitHub Pages autorisée. Puis publier **une nouvelle version du même Site**, en surveillant les éventuelles migrations et erreurs.
5. Vérifier `GET https://besoin2027.hamidtawfiq2.chatgpt.site/api/controle/health` : **HTTP 200**, JSON `{"ready":true}`. Toute réponse 404, 503 ou réponse `ready:false` signifie que le service est **non prêt**.
6. Avec le compte coordinateur, effectuer un test limité d'import (un petit fichier Excel **CAB / NomAgence**) dans chacun des quatre modules : `bouclage_am`, `notification_enregistree`, `notification_recommandee`, `hdg`. Tester les deux modes : fichier global (distribution automatique) et fichier d'une seule agence (sans affecter les autres). Vérifier également les alias confirmés, les corrections de rattachement, la suppression d'une association et les observations en anomalie.
7. Depuis une autre session/navigateur, sélectionner une agence et vérifier qu'elle ne reçoit **que ses propres codes**, y compris les CAB rattachés à son nom officiel. Vérifier **OK**, **Anomalie**, les compteurs **Codes traités/Codes restants**, le suivi coordinateur et l'export. Contrôler que les enregistrements des anciennes applications n'ont pas été modifiés.

## Précautions

- **Ne pas créer de deuxième base** : le Site et ses anciens enregistrements doivent rester intacts.
- **Ne pas réutiliser une migration de test** contenant des commandes de suppression.
- Si les fichiers GitHub diffèrent du projet Sites déployé, analyser la différence et préserver l'ancienne fonctionnalité avant de synchroniser le backend.
- Les agences sont choisies sans authentification individuelle dans la version actuelle. Avant diffusion large des codes réels, restreindre l'accès ou installer un mécanisme de contrôle d'accès par agence ; la simple sélection de la liste ne prouve pas l'identité du visiteur.
- Après déploiement, valider le fonctionnement **sur le Site réellement publié**, pas uniquement sur GitHub Pages.
