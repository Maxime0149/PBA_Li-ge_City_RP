// ============================================================
// AUTHENTIFICATION & CONTRÔLE D'ACCÈS
// Utilise Supabase Auth. Les permissions réelles sont appliquées
// côté serveur par les policies RLS de schema.sql — ce fichier ne
// fait que guider l'interface (masquer des liens, rediriger),
// il ne doit jamais être considéré comme la source de vérité.
// ============================================================

/**
 * Retourne la session en cours, ou null si personne n'est connecté.
 */
async function getSession() {
  const { data: { session } } = await supabaseClient.auth.getSession();
  return session;
}

/**
 * Retourne le profil complet (table profiles) de l'utilisateur connecté.
 */
async function getCurrentProfile() {
  const session = await getSession();
  if (!session) return null;
  const { data, error } = await supabaseClient
    .from('profiles')
    .select('*')
    .eq('id', session.user.id)
    .single();
  if (error) { console.error(error); return null; }
  return data;
}

/**
 * Supabase Auth attend un email en interne. Pour permettre une connexion
 * par simple pseudo RP (sans email réel), on génère ici un email interne
 * invisible pour l'utilisateur : "monpseudo" -> "monpseudo@pba.local".
 * Ce n'est jamais montré à l'utilisateur ni utilisé pour lui envoyer quoi
 * que ce soit — c'est uniquement un identifiant technique.
 */
function pseudoToInternalEmail(pseudo) {
  const clean = pseudo
    .trim()
    .toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '') // enlève les accents
    .replace(/[^a-z0-9]/g, '');                          // garde lettres/chiffres uniquement
  return `${clean}@pba.local`;
}

/**
 * Connexion par pseudo / mot de passe.
 */
async function signIn(pseudo, password) {
  return supabaseClient.auth.signInWithPassword({ email: pseudoToInternalEmail(pseudo), password });
}

/**
 * Inscription — crée l'utilisateur Auth ; le profil (rôle "client" par
 * défaut) est créé automatiquement par le trigger handle_new_user(), qui
 * récupère le pseudo depuis les métadonnées.
 */
async function signUp(pseudo, password, nom, prenom) {
  return supabaseClient.auth.signUp({
    email: pseudoToInternalEmail(pseudo),
    password,
    options: { data: { nom, prenom, pseudo: pseudo.trim() } }
  });
}

/**
 * Calcule le chemin vers la racine du site selon la page où l'on se trouve
 * (ex: depuis /admin/accounts.html il faut remonter d'un cran avec "../").
 * Sans ça, un lien relatif "login.html" pointerait vers /admin/login.html
 * (404) au lieu de /login.html — c'est le bug de la déconnexion en 404.
 */
function rootPath() {
  return window.location.pathname.includes('/admin/') ? '../' : './';
}

/**
 * Connexion via Discord (OAuth). Redirige vers Discord, puis revient sur
 * complete-profil.html qui termine l'inscription (nom/prénom RP) si besoin.
 */
async function signInWithDiscord() {
  const redirectTo = new URL('complete-profil.html', window.location.href).toString();
  return supabaseClient.auth.signInWithOAuth({
    provider: 'discord',
    options: { redirectTo }
  });
}

async function signOut() {
  await supabaseClient.auth.signOut();
  window.location.href = rootPath() + 'login.html';
}

/**
 * À appeler en haut de chaque page protégée.
 * allowedRoles : tableau de rôles autorisés (ex: ['administrateur','directeur']).
 * Si aucune session, ou si le rôle du profil n'est pas dans la liste,
 * redirige vers login.html. Retourne le profil si l'accès est autorisé.
 *
 * Rappel : ceci est une protection d'INTERFACE. La vraie barrière est
 * la RLS côté base de données — un utilisateur qui contournerait cette
 * fonction ne pourrait de toute façon pas lire/écrire des données qui
 * ne lui sont pas autorisées.
 */
async function requireRole(allowedRoles) {
  const profile = await getCurrentProfile();
  if (!profile) {
    window.location.href = rootPath() + 'login.html';
    return null;
  }
  if (allowedRoles && !allowedRoles.includes(profile.role)) {
    window.location.href = rootPath() + 'index.html';
    return null;
  }
  return profile;
}

/** Formatage monétaire belge : 1 234,00 € */
function formatEUR(n) {
  return Number(n).toLocaleString('fr-BE', { style: 'currency', currency: 'EUR' });
}

/** Formatage de date belge : JJ/MM/AAAA */
function formatDateBE(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('fr-BE');
}

/** Petit système de toast pour confirmer les actions */
function toast(message) {
  let container = document.querySelector('.toast-container');
  if (!container) {
    container = document.createElement('div');
    container.className = 'toast-container';
    document.body.appendChild(container);
  }
  const el = document.createElement('div');
  el.className = 'toast';
  el.textContent = message;
  container.appendChild(el);
  setTimeout(() => el.remove(), 4000);
}
