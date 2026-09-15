-- ============================================================================
-- PBA — PACIFIQUE BANQUE & ASSURANCES
-- Schéma PostgreSQL / Supabase complet
-- ============================================================================
-- À exécuter dans l'éditeur SQL de ton projet Supabase (Database → SQL Editor)
-- en une seule fois, de haut en bas. Nécessite l'extension pgcrypto
-- (activée par défaut sur Supabase) pour gen_random_uuid().
-- ============================================================================


-- ============================================================================
-- 1. TYPES ÉNUMÉRÉS
-- ============================================================================

create type user_role as enum ('client','employe','responsable','directeur','administrateur');
create type account_type as enum ('compte_a_vue','compte_epargne','compte_professionnel');
create type account_status as enum ('actif','bloque','ferme');
create type transaction_type as enum ('virement','depot','retrait','paiement','salaire','frais_bancaires','credit','remboursement','correction_administrative');
create type transaction_status as enum ('en_attente','validee','refusee','annulee');
create type card_type as enum ('debit','credit');
create type card_status as enum ('active','bloquee','expiree','annulee');
create type credit_type as enum ('consommation','personnel','automobile','hypothecaire','professionnel');
create type credit_status as enum ('en_attente','en_analyse','accepte','refuse','termine');
create type news_status as enum ('brouillon','publie','depublie');


-- ============================================================================
-- 2. TABLES
-- ============================================================================

-- Agences (créée avant profiles ; le lien directeur_id est ajouté après coup
-- pour éviter une dépendance circulaire à la création)
create table public.branches (
  id uuid primary key default gen_random_uuid(),
  nom text not null,
  adresse text not null,
  telephone text,
  horaires text,
  directeur_id uuid,
  services text[] default '{}',
  statut text not null default 'actif',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Profils utilisateurs — un profil par utilisateur Supabase Auth (auth.users)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nom text not null,
  prenom text not null,
  email text not null,
  pseudo text unique,
  telephone text,
  adresse text,
  date_naissance date,
  numero_client text unique not null default ('PBA-' || upper(substr(md5(random()::text), 1, 8))),
  date_creation timestamptz not null default now(),
  statut text not null default 'actif',              -- actif / suspendu
  role user_role not null default 'client',
  agence_principale uuid references public.branches(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.branches
  add constraint branches_directeur_fk foreign key (directeur_id) references public.profiles(id);

-- Comptes bancaires
create table public.bank_accounts (
  id uuid primary key default gen_random_uuid(),
  numero_compte text unique not null default (
    'BE' || lpad(floor(random() * 100000000000000000)::text, 14, '0')
  ),
  client_id uuid not null references public.profiles(id),
  type_compte account_type not null,
  solde numeric(14,2) not null default 0,
  devise text not null default 'EUR',
  statut account_status not null default 'actif',
  agence_id uuid references public.branches(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Cartes bancaires — jamais le numéro complet, uniquement une version masquée
create table public.bank_cards (
  id uuid primary key default gen_random_uuid(),
  numero_masque text not null,          -- ex: **** **** **** 4821
  type card_type not null default 'debit',
  titulaire_id uuid not null references public.profiles(id),
  compte_id uuid not null references public.bank_accounts(id),
  date_expiration date not null,
  statut card_status not null default 'active',
  created_at timestamptz not null default now()
);

-- Transactions — historique immuable (pas d'UPDATE ni DELETE autorisés)
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  compte_source uuid references public.bank_accounts(id),
  compte_destination uuid references public.bank_accounts(id),
  montant numeric(14,2) not null,
  type transaction_type not null,
  description text,
  date timestamptz not null default now(),
  statut transaction_status not null default 'validee',
  utilisateur_id uuid references public.profiles(id),  -- qui a effectué l'opération
  created_at timestamptz not null default now()
);

-- Crédits
create table public.credits (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles(id),
  type_credit credit_type not null,
  montant_demande numeric(14,2) not null,
  montant_accorde numeric(14,2),
  taux numeric(5,2),
  duree_mois integer,
  mensualite numeric(14,2),
  date_demande timestamptz not null default now(),
  statut credit_status not null default 'en_attente',
  conseiller_id uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Journal d'audit — insert-only, jamais modifié ni supprimé
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  utilisateur_id uuid references public.profiles(id),
  action text not null,
  objet_type text,
  objet_id uuid,
  ancienne_valeur jsonb,
  nouvelle_valeur jsonb,
  date_heure timestamptz not null default now()
);

-- Notifications
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  utilisateur_id uuid not null references public.profiles(id),
  titre text not null,
  contenu text not null,
  lu boolean not null default false,
  created_at timestamptz not null default now()
);

-- Annonces / actualités
create table public.news (
  id uuid primary key default gen_random_uuid(),
  titre text not null,
  contenu text not null,
  image_url text,
  auteur_id uuid references public.profiles(id),
  statut news_status not null default 'brouillon',
  date_publication timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Contenu du site public (CMS) — tarifs, services, offres, horaires, coordonnées...
create table public.site_content (
  id uuid primary key default gen_random_uuid(),
  section text not null,       -- 'tarifs' | 'services' | 'offres_credit' | 'assurances' | 'coordonnees' | 'messages'
  cle text not null,
  valeur jsonb not null,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now(),
  unique (section, cle)
);

-- Notes internes sur un client (visibles par le personnel uniquement)
create table public.client_notes (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles(id),
  auteur_id uuid not null references public.profiles(id),
  contenu text not null,
  created_at timestamptz not null default now()
);


-- ============================================================================
-- 3. FONCTIONS UTILITAIRES (SECURITY DEFINER — évitent la récursion RLS)
-- ============================================================================

create or replace function public.current_role_name()
returns user_role
language sql security definer stable
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_staff()
returns boolean
language sql security definer stable
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('employe','responsable','directeur','administrateur')
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql security definer stable
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('directeur','administrateur')
  );
$$;


-- ============================================================================
-- 4. TRIGGERS
-- ============================================================================

-- 4.1 Création automatique du profil à l'inscription (auth.users -> profiles)
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  v_pseudo text;
begin
  -- Le pseudo vient soit du formulaire d'inscription classique ("pseudo"),
  -- soit du profil Discord ("user_name" / "full_name") en cas de connexion OAuth.
  v_pseudo := coalesce(
    new.raw_user_meta_data->>'pseudo',
    new.raw_user_meta_data->>'user_name',
    new.raw_user_meta_data->>'full_name',
    split_part(new.email, '@', 1)
  );
  v_pseudo := regexp_replace(lower(v_pseudo), '[^a-z0-9]', '', 'g');
  if v_pseudo is null or v_pseudo = '' then
    v_pseudo := 'joueur' || substr(new.id::text, 1, 6);
  end if;

  begin
    insert into public.profiles (id, nom, prenom, email, pseudo, role)
    values (
      new.id,
      coalesce(new.raw_user_meta_data->>'nom', 'À compléter'),
      coalesce(new.raw_user_meta_data->>'prenom', 'À compléter'),
      new.email,
      v_pseudo,
      'client'
    );
  exception when unique_violation then
    -- pseudo déjà pris (ex: même nom Discord) -> on ajoute un suffixe
    insert into public.profiles (id, nom, prenom, email, pseudo, role)
    values (
      new.id,
      coalesce(new.raw_user_meta_data->>'nom', 'À compléter'),
      coalesce(new.raw_user_meta_data->>'prenom', 'À compléter'),
      new.email,
      v_pseudo || substr(new.id::text, 1, 4),
      'client'
    );
  end;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4.2 updated_at automatique
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger trg_branches_updated before update on public.branches
  for each row execute function public.set_updated_at();
create trigger trg_accounts_updated before update on public.bank_accounts
  for each row execute function public.set_updated_at();
create trigger trg_credits_updated before update on public.credits
  for each row execute function public.set_updated_at();
create trigger trg_news_updated before update on public.news
  for each row execute function public.set_updated_at();

-- 4.3 Interdiction de modifier le solde d'un compte autrement que via la
-- fonction admin_adjust_balance() ou transfer_funds() ci-dessous, afin que
-- toute variation laisse systématiquement une trace (transaction + audit).
create or replace function public.protect_balance_change()
returns trigger language plpgsql as $$
begin
  if new.solde is distinct from old.solde
     and coalesce(current_setting('pba.allow_balance_change', true), '') <> '1' then
    raise exception 'Modification directe du solde interdite — utiliser admin_adjust_balance() ou transfer_funds().';
  end if;
  return new;
end;
$$;

create trigger trg_protect_balance
  before update on public.bank_accounts
  for each row execute function public.protect_balance_change();

-- 4.4 Journalisation automatique des modifications sensibles
create or replace function public.log_change()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.audit_logs (utilisateur_id, action, objet_type, objet_id, ancienne_valeur, nouvelle_valeur)
  values (
    auth.uid(),
    tg_op || ' ' || tg_table_name,
    tg_table_name,
    coalesce(new.id, old.id),
    to_jsonb(old),
    to_jsonb(new)
  );
  return coalesce(new, old);
end;
$$;

create trigger trg_audit_profiles after update on public.profiles
  for each row execute function public.log_change();
create trigger trg_audit_accounts after update on public.bank_accounts
  for each row execute function public.log_change();
create trigger trg_audit_credits after update on public.credits
  for each row execute function public.log_change();
create trigger trg_audit_cards after update on public.bank_cards
  for each row execute function public.log_change();


-- ============================================================================
-- 5. FONCTIONS RPC MÉTIER (appelées depuis le frontend via supabase.rpc())
--    Toutes vérifient le rôle de l'appelant elles-mêmes : ne jamais faire
--    confiance à ce qu'envoie le navigateur.
-- ============================================================================

-- 5.1 Ajustement administratif d'un solde (crédit / débit / correction)
create or replace function public.admin_adjust_balance(
  p_account_id uuid,
  p_montant numeric,          -- positif = crédit, négatif = débit
  p_motif text
)
returns numeric
language plpgsql security definer
set search_path = public
as $$
declare
  v_old_solde numeric(14,2);
  v_new_solde numeric(14,2);
  v_client_id uuid;
begin
  if not public.is_staff() then
    raise exception 'Action réservée au personnel autorisé.';
  end if;

  select solde, client_id into v_old_solde, v_client_id
  from public.bank_accounts where id = p_account_id for update;

  if v_old_solde is null then
    raise exception 'Compte introuvable.';
  end if;

  v_new_solde := v_old_solde + p_montant;

  perform set_config('pba.allow_balance_change', '1', true);
  update public.bank_accounts set solde = v_new_solde where id = p_account_id;
  perform set_config('pba.allow_balance_change', '0', true);

  insert into public.transactions (compte_destination, montant, type, description, utilisateur_id, statut)
  values (p_account_id, p_montant, 'correction_administrative', p_motif, auth.uid(), 'validee');

  insert into public.audit_logs (utilisateur_id, action, objet_type, objet_id, ancienne_valeur, nouvelle_valeur)
  values (
    auth.uid(), 'admin_adjust_balance', 'bank_accounts', p_account_id,
    jsonb_build_object('solde', v_old_solde),
    jsonb_build_object('solde', v_new_solde, 'difference', p_montant, 'motif', p_motif)
  );

  insert into public.notifications (utilisateur_id, titre, contenu)
  values (v_client_id, 'Mouvement sur votre compte',
          'Une opération de ' || p_montant || ' € a été enregistrée sur votre compte. Motif : ' || p_motif);

  return v_new_solde;
end;
$$;

-- 5.2 Virement entre deux comptes (initié par le client ou le personnel)
create or replace function public.transfer_funds(
  p_source uuid,
  p_destination uuid,
  p_montant numeric,
  p_description text
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_source_owner uuid;
  v_source_solde numeric(14,2);
begin
  if p_montant <= 0 then
    raise exception 'Le montant doit être positif.';
  end if;

  select client_id, solde into v_source_owner, v_source_solde
  from public.bank_accounts where id = p_source for update;

  if v_source_owner is null then
    raise exception 'Compte source introuvable.';
  end if;

  if v_source_owner <> auth.uid() and not public.is_staff() then
    raise exception 'Vous ne pouvez virer des fonds que depuis vos propres comptes.';
  end if;

  if v_source_solde < p_montant then
    raise exception 'Solde insuffisant.';
  end if;

  perform set_config('pba.allow_balance_change', '1', true);
  update public.bank_accounts set solde = solde - p_montant where id = p_source;
  update public.bank_accounts set solde = solde + p_montant where id = p_destination;
  perform set_config('pba.allow_balance_change', '0', true);

  insert into public.transactions (compte_source, compte_destination, montant, type, description, utilisateur_id, statut)
  values (p_source, p_destination, p_montant, 'virement', p_description, auth.uid(), 'validee');
end;
$$;

-- 5.3 Traitement d'une demande de crédit
create or replace function public.process_credit(
  p_credit_id uuid,
  p_statut credit_status,
  p_montant_accorde numeric default null,
  p_taux numeric default null,
  p_mensualite numeric default null
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_client_id uuid;
begin
  if not public.is_staff() then
    raise exception 'Action réservée au personnel autorisé.';
  end if;

  select client_id into v_client_id from public.credits where id = p_credit_id;

  update public.credits
  set statut = p_statut,
      montant_accorde = coalesce(p_montant_accorde, montant_accorde),
      taux = coalesce(p_taux, taux),
      mensualite = coalesce(p_mensualite, mensualite),
      conseiller_id = auth.uid()
  where id = p_credit_id;

  insert into public.notifications (utilisateur_id, titre, contenu)
  values (
    v_client_id,
    'Mise à jour de votre demande de crédit',
    case p_statut
      when 'accepte' then 'Votre demande de crédit a été acceptée.'
      when 'refuse' then 'Votre demande de crédit a été refusée.'
      when 'en_analyse' then 'Votre demande de crédit est en cours d''analyse.'
      else 'Le statut de votre demande de crédit a changé.'
    end
  );
end;
$$;

-- 5.4 Blocage / déblocage / fermeture d'un compte
create or replace function public.set_account_status(p_account_id uuid, p_statut account_status)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_client_id uuid;
begin
  if not public.is_staff() then
    raise exception 'Action réservée au personnel autorisé.';
  end if;

  select client_id into v_client_id from public.bank_accounts where id = p_account_id;

  update public.bank_accounts set statut = p_statut where id = p_account_id;

  insert into public.notifications (utilisateur_id, titre, contenu)
  values (v_client_id, 'Statut de compte modifié', 'Le statut de votre compte est désormais : ' || p_statut);
end;
$$;


-- ============================================================================
-- 6. ROW LEVEL SECURITY
-- ============================================================================

alter table public.profiles enable row level security;
alter table public.branches enable row level security;
alter table public.bank_accounts enable row level security;
alter table public.bank_cards enable row level security;
alter table public.transactions enable row level security;
alter table public.credits enable row level security;
alter table public.audit_logs enable row level security;
alter table public.notifications enable row level security;
alter table public.news enable row level security;
alter table public.site_content enable row level security;
alter table public.client_notes enable row level security;

-- profiles : chacun voit son profil ; le personnel voit tous les profils
create policy "profiles_select" on public.profiles for select
  using (id = auth.uid() or public.is_staff());
create policy "profiles_update_self" on public.profiles for update
  using (id = auth.uid() or public.is_admin());
-- (l'INSERT est géré exclusivement par le trigger handle_new_user, aucune policy INSERT nécessaire)

-- branches : lecture publique, écriture réservée à la direction/admin
create policy "branches_select_public" on public.branches for select using (true);
create policy "branches_write_admin" on public.branches for all
  using (public.is_admin()) with check (public.is_admin());

-- bank_accounts : le client voit ses comptes, le personnel voit tout
create policy "accounts_select" on public.bank_accounts for select
  using (client_id = auth.uid() or public.is_staff());
create policy "accounts_insert_staff" on public.bank_accounts for insert
  with check (public.is_staff());
create policy "accounts_update_staff" on public.bank_accounts for update
  using (public.is_staff());

-- bank_cards : le titulaire et le personnel
create policy "cards_select" on public.bank_cards for select
  using (titulaire_id = auth.uid() or public.is_staff());
create policy "cards_write_staff" on public.bank_cards for all
  using (public.is_staff()) with check (public.is_staff());

-- transactions : visibles par les propriétaires des comptes concernés et le personnel
-- immuables : aucune policy UPDATE / DELETE n'est créée (donc interdit à tous via l'API)
create policy "transactions_select" on public.transactions for select
  using (
    public.is_staff()
    or compte_source in (select id from public.bank_accounts where client_id = auth.uid())
    or compte_destination in (select id from public.bank_accounts where client_id = auth.uid())
  );
create policy "transactions_insert_staff" on public.transactions for insert
  with check (public.is_staff());

-- credits : le client voit et crée ses demandes, le personnel gère tout
create policy "credits_select" on public.credits for select
  using (client_id = auth.uid() or public.is_staff());
create policy "credits_insert_self" on public.credits for insert
  with check (client_id = auth.uid() or public.is_staff());
create policy "credits_update_staff" on public.credits for update
  using (public.is_staff());

-- audit_logs : lecture réservée au personnel ; écriture uniquement via triggers/RPC (security definer)
create policy "audit_select_staff" on public.audit_logs for select
  using (public.is_staff());

-- notifications : chacun voit et marque comme lues les siennes
create policy "notifications_select" on public.notifications for select
  using (utilisateur_id = auth.uid());
create policy "notifications_update_self" on public.notifications for update
  using (utilisateur_id = auth.uid());
create policy "notifications_insert_staff" on public.notifications for insert
  with check (public.is_staff());

-- news : publiées visibles de tous, brouillons visibles du personnel, écriture personnel
create policy "news_select_public" on public.news for select
  using (statut = 'publie' or public.is_staff());
create policy "news_write_staff" on public.news for all
  using (public.is_staff()) with check (public.is_staff());

-- site_content : lecture publique, écriture personnel
create policy "content_select_public" on public.site_content for select using (true);
create policy "content_write_staff" on public.site_content for all
  using (public.is_staff()) with check (public.is_staff());

-- client_notes : réservé au personnel
create policy "notes_staff_only" on public.client_notes for all
  using (public.is_staff()) with check (public.is_staff());


-- ============================================================================
-- 7. TEMPS RÉEL — active les tables pertinentes pour Supabase Realtime
-- ============================================================================

alter publication supabase_realtime add table public.bank_accounts;
alter publication supabase_realtime add table public.transactions;
alter publication supabase_realtime add table public.credits;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.news;
alter publication supabase_realtime add table public.bank_cards;


-- ============================================================================
-- 8. DONNÉES INITIALES (agences + contenu CMS de départ)
-- ============================================================================

insert into public.branches (nom, adresse, telephone, horaires, services) values
  ('PBA Bruxelles', 'Rue de la Pacifique 12, 1000 Bruxelles', '+32 2 512 44 08', 'Lun–Ven 9h–17h', array['Comptes','Crédits','Assurances']),
  ('PBA Liège',     'Rue de la Banque 25, 4000 Liège',        '+32 4 223 17 56', 'Lun–Ven 9h–17h', array['Comptes','Crédits','Assurances']),
  ('PBA Namur',     'Avenue de la Monnaie 8, 5000 Namur',     '+32 81 44 62 19', 'Lun–Ven 9h–16h30', array['Comptes','Crédits']),
  ('PBA Charleroi', 'Boulevard du Pacifique 3, 6000 Charleroi','+32 71 30 55 12','Lun–Ven 9h–17h', array['Comptes','Assurances']),
  ('PBA Mons',      'Rue des Épargnants 14, 7000 Mons',       '+32 65 84 21 07', 'Lun–Ven 9h–16h30', array['Comptes']),
  ('PBA Anvers',    'Beursstraat 41, 2000 Anvers',            '+32 3 216 90 33', 'Lun–Ven 9h–17h', array['Comptes','Crédits','Assurances']),
  ('PBA Gand',      'Kredietlaan 6, 9000 Gand',                '+32 9 265 48 20', 'Lun–Ven 9h–17h', array['Comptes','Crédits']),
  ('PBA Verviers',  'Rue du Crédit 19, 4800 Verviers',         '+32 87 33 12 44', 'Lun–Ven 9h–16h', array['Comptes']),
  ('PBA Hasselt',   'Spaarstraat 5, 3500 Hasselt',              '+32 11 22 87 60', 'Lun–Ven 9h–16h30', array['Comptes','Assurances']);

insert into public.site_content (section, cle, valeur) values
  ('coordonnees', 'telephone_general', '"+32 78 05 12 30"'),
  ('coordonnees', 'email_general', '"contact@pba-banque.be"'),
  ('tarifs', 'compte_a_vue', '{"prix": "2,50 €/mois"}'),
  ('tarifs', 'compte_epargne', '{"prix": "Sans frais"}'),
  ('tarifs', 'compte_professionnel', '{"prix": "12,00 €/mois"}'),
  ('offres_credit', 'taux_hypothecaire_min', '"0,45 %"');

-- ============================================================================
-- MIGRATION — à exécuter uniquement si tu avais DÉJÀ créé ce schéma avant
-- l'ajout de la connexion par pseudo (sinon la colonne pseudo est déjà là
-- et cette section ne sert à rien).
-- ============================================================================
-- alter table public.profiles add column if not exists pseudo text unique;
--
-- create or replace function public.handle_new_user()
-- returns trigger language plpgsql security definer set search_path = public as $$
-- declare
--   v_pseudo text;
-- begin
--   v_pseudo := coalesce(
--     new.raw_user_meta_data->>'pseudo',
--     new.raw_user_meta_data->>'user_name',
--     new.raw_user_meta_data->>'full_name',
--     split_part(new.email, '@', 1)
--   );
--   v_pseudo := regexp_replace(lower(v_pseudo), '[^a-z0-9]', '', 'g');
--   if v_pseudo is null or v_pseudo = '' then
--     v_pseudo := 'joueur' || substr(new.id::text, 1, 6);
--   end if;
--   begin
--     insert into public.profiles (id, nom, prenom, email, pseudo, role)
--     values (new.id, coalesce(new.raw_user_meta_data->>'nom','À compléter'),
--             coalesce(new.raw_user_meta_data->>'prenom','À compléter'), new.email, v_pseudo, 'client');
--   exception when unique_violation then
--     insert into public.profiles (id, nom, prenom, email, pseudo, role)
--     values (new.id, coalesce(new.raw_user_meta_data->>'nom','À compléter'),
--             coalesce(new.raw_user_meta_data->>'prenom','À compléter'), new.email, v_pseudo || substr(new.id::text,1,4), 'client');
--   end;
--   return new;
-- end;
-- $$;

-- ============================================================================
-- FIN DU SCHÉMA
-- Prochaine étape : crée ton premier compte via l'inscription du site
-- (login.html), puis remonte manuellement son rôle en 'administrateur' :
--
--   update public.profiles set role = 'administrateur' where pseudo = 'tonpseudo';
-- ============================================================================
