// ============================================================
// CONFIGURATION SUPABASE
// ============================================================
// Remplace ces deux valeurs par celles de TON projet Supabase :
// Tableau de bord Supabase → Project Settings → API
//   - "Project URL"       → SUPABASE_URL
//   - "anon public" key   → SUPABASE_ANON_KEY
//
// IMPORTANT : la clé "anon public" est faite pour être exposée
// côté client — ce n'est pas un secret, la sécurité réelle vient
// des policies RLS définies dans schema.sql. Ne mets JAMAIS la
// "service_role" key ici.
// ============================================================

const SUPABASE_URL = "https://aucdpxtctgedeocqssyr.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_gnE8gn33EoZxxkdpvPohkw_bQJjUtKv";

// Le script @supabase/supabase-js doit être chargé avant ce fichier
// (voir la balise <script> dans le <head> de chaque page).
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
