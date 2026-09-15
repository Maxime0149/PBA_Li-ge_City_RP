# PBA — Pacifique Banque & Assurances
Plateforme bancaire RP complète : site public, espace client, panneau
d'administration multi-rôles, base de données centralisée sur Supabase.

## 1. Créer ton projet Supabase (gratuit)

1. Va sur **https://supabase.com** → *Start your project* → connecte-toi avec GitHub ou un email.
2. Clique **New project**. Choisis un nom (ex: `pba-banque`), un mot de passe pour la base (garde-le précieusement), une région proche (Europe).
3. Attends 1 à 2 minutes que le projet soit prêt.

## 2. Créer les tables

1. Dans le tableau de bord du projet, ouvre **SQL Editor** (menu de gauche).
2. Clique **New query**.
3. Colle **tout le contenu** du fichier `schema.sql` fourni ici, puis clique **Run**.
   → Cela crée toutes les tables, les règles de sécurité (RLS), les triggers,
   les fonctions, et insère les 9 agences de départ.

## 3. Récupérer tes identifiants

1. Menu de gauche → **Project Settings** → **API**.
2. Copie :
   - **Project URL**
   - **anon public** key (⚠️ pas la `service_role` — celle-là ne doit jamais quitter Supabase)
3. Ouvre `assets/config.js` dans ce dossier et remplace les deux valeurs :

```js
const SUPABASE_URL = "https://TON-PROJET.supabase.co";
const SUPABASE_ANON_KEY = "ta-cle-anon-publique";
```

## 4. Créer ton premier compte administrateur

1. Ouvre `login.html` dans ton navigateur (double-clic sur le fichier, ou
   héberge le dossier — voir section 6).
2. Onglet **Créer un compte**, inscris-toi avec un pseudo RP (tu deviens "client" par défaut).
   → Le site n'utilise pas de vrai email : ton pseudo suffit pour te connecter.
3. **Important :** dans Supabase, va dans **Authentication → Providers → Email**
   et désactive l'option **"Confirm email"**. Comme le site génère un email
   interne invisible (`tonpseudo@pba.local`), personne ne peut recevoir le
   mail de confirmation — il faut donc que Supabase n'en exige pas.
4. Retourne dans Supabase → **SQL Editor** → exécute :

```sql
update public.profiles set role = 'administrateur' where pseudo = 'tonpseudo';
```

5. Reconnecte-toi : tu arrives maintenant sur `/admin/index.html`.

## 4bis. (Optionnel) Activer la connexion via Discord

1. Sur **discord.com/developers/applications**, crée une application, puis
   dans **OAuth2 → General**, récupère le **Client ID** et le **Client Secret**.
2. Dans Supabase : **Authentication → Providers → Discord**, active-le et colle
   ces deux valeurs. Supabase affiche alors une **Callback URL**.
3. Colle cette Callback URL dans Discord Developer Portal → **OAuth2 → General → Redirects**.
4. C'est tout côté configuration — le bouton "Continuer avec Discord" est déjà
   présent sur `login.html`, et `complete-profil.html` demande automatiquement
   le nom/prénom RP à la première connexion (Discord ne les fournit pas).

## 5. Structure du projet

```
pba-platform/
├── schema.sql              # Schéma complet à exécuter dans Supabase
├── index.html               # Site public (agences/actualités = CMS)
├── login.html                # Connexion / inscription
├── complete-profil.html      # Complète le profil après une 1ère connexion Discord
├── espace-client.html        # Espace client (comptes, cartes, virements, crédits)
├── admin/
│   ├── index.html            # Tableau de bord (statistiques)
│   ├── clients.html          # Fiche client, notes, suspension
│   ├── accounts.html         # Comptes : blocage, création, ajustement de solde
│   ├── credits.html          # Traitement des demandes de crédit
│   ├── news.html             # CMS — annonces
│   ├── branches.html         # CMS — agences
│   └── audit.html            # Journal d'audit (lecture seule)
└── assets/
    ├── config.js              # Identifiants Supabase (à compléter)
    ├── auth.js                # Authentification / permissions
    └── style.css              # Styles partagés
```

## 6. Héberger le site (pour que tout le monde y accède)

Ce dossier est 100 % statique (HTML/CSS/JS) — aucune compilation nécessaire.
Options simples et gratuites :
- **Netlify** ou **Vercel** : glisser-déposer le dossier sur leur interface web.
- **GitHub Pages** : pousser le dossier dans un repo, activer Pages dans les réglages.

## 7. Rôles et permissions

| Rôle            | Accès |
|---|---|
| `client`         | Son propre espace uniquement |
| `employe`        | Consultation clients/comptes nécessaires à son travail |
| `responsable`    | Gestion d'équipe + opérations autorisées |
| `directeur`      | Gestion de son agence, agences (`/admin/branches`) |
| `administrateur` | Accès complet |

Les permissions sont appliquées **dans la base de données** (Row Level
Security), pas seulement dans l'interface : même en modifiant le code HTML,
un client ne peut pas lire les données d'un autre client ni écrire dans les
tables réservées au personnel.

Pour changer le rôle d'un utilisateur, exécute dans Supabase :
```sql
update public.profiles set role = 'employe' where numero_client = 'PBA-XXXXXXXX';
```
(Une interface de gestion des permissions en admin peut être ajoutée dans une
prochaine itération si tu veux éviter de passer par le SQL Editor.)

## 8. Sécurité — ce qui est déjà en place

- Aucun mot de passe, aucune clé secrète dans le code : la clé `anon` est
  publique par design, la vraie sécurité vient des policies RLS.
- Les soldes ne peuvent **jamais** être modifiés directement : seules les
  fonctions `admin_adjust_balance()` et `transfer_funds()` y sont autorisées,
  et chacune écrit automatiquement une transaction + une entrée d'audit.
- Les transactions et le journal d'audit sont **immuables** : aucune policy
  UPDATE/DELETE n'existe pour ces tables, donc aucune modification n'est
  possible via l'API, quel que soit le rôle.

## 9. Non fait dans cette première version (à prévoir)

- **Intégration FiveM / Réva Gestion** : l'architecture (base centralisée,
  fonctions RPC) est prête à être appelée depuis une API externe sécurisée,
  mais aucune connexion réelle n'existe — à construire séparément avec ses
  propres clés d'API, jamais exposées côté client.
- **Interface de gestion des permissions** : pour l'instant, changer un rôle
  se fait via le SQL Editor (section 7). Une page `/admin/staff.html` peut
  être ajoutée ensuite.
- **Notifications temps réel visuelles avancées** (cloche déroulante) :
  le compteur et les toasts fonctionnent déjà en temps réel ; un centre de
  notifications complet peut être ajouté.
- **Documents clients** (dépôt de fichiers) : nécessite Supabase Storage,
  non configuré ici.
