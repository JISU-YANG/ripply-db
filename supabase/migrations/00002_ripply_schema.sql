-- Ripply 데이터 모델 (docs/데이터-문서.md)
-- 기존 profiles 스키마 제거 후 전체 스키마 적용

-- ==========================================
-- 0. Legacy cleanup
-- ==========================================
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop table if exists public.profiles;

-- ==========================================
-- Helpers
-- ==========================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ==========================================
-- 1. users (사용자) — auth.users 와 1:1
-- ==========================================
create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email varchar(255) not null unique,
  nickname varchar(50) not null,
  profile_image_url text,
  provider varchar(20) not null check (provider in ('KAKAO', 'GOOGLE')),
  social_id varchar(255) not null,
  token_balance integer not null default 0 check (token_balance >= 0),
  total_collected_count integer not null default 0 check (total_collected_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index idx_users_provider_social on public.users (provider, social_id);

create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

-- ==========================================
-- 2. card_packs (상점 카드팩)
-- ==========================================
create table public.card_packs (
  id uuid primary key default gen_random_uuid(),
  title varchar(100) not null,
  description text,
  price_tokens integer not null default 0 check (price_tokens >= 0),
  max_supply integer check (max_supply is null or max_supply >= 0),
  current_sales integer not null default 0 check (current_sales >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ==========================================
-- 3. card_themes (카드 테마 / 스킨)
-- ==========================================
create table public.card_themes (
  id uuid primary key default gen_random_uuid(),
  card_pack_id uuid references public.card_packs (id) on delete set null,
  theme_code varchar(50) not null unique,
  name varchar(100) not null,
  preview_image_url text,
  is_premium boolean not null default false,
  created_at timestamptz not null default now()
);

-- ==========================================
-- 4. cards (문장 카드)
-- ==========================================
create table public.cards (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.users (id) on delete cascade,
  card_type varchar(20) not null default 'BASIC' check (card_type in ('BASIC', 'PREMIUM')),
  theme_id uuid references public.card_themes (id) on delete set null,
  quote_text text not null,
  source_text varchar(200),
  collect_count integer not null default 0 check (collect_count >= 0),
  grade varchar(20) not null default 'BASIC' check (
    grade in ('BASIC', 'RARE', 'EPIC', 'UNIQUE', 'LEGENDARY')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_premium_card_theme check (
    (card_type = 'BASIC') or (card_type = 'PREMIUM' and theme_id is not null)
  )
);

create index idx_cards_creator_id on public.cards (creator_id);
create index idx_cards_collect_count on public.cards (collect_count desc);
create index idx_cards_created_at on public.cards (created_at desc);

create trigger cards_set_updated_at
  before update on public.cards
  for each row execute function public.set_updated_at();

-- ==========================================
-- 5. collections (수집 내역)
-- ==========================================
create table public.collections (
  id bigserial primary key,
  user_id uuid not null references public.users (id) on delete cascade,
  card_id uuid not null references public.cards (id) on delete cascade,
  collection_number integer not null check (collection_number >= 0),
  created_at timestamptz not null default now(),
  constraint uq_card_collection_number unique (card_id, collection_number)
);

create index idx_collections_user_id on public.collections (user_id);
create unique index idx_collections_user_card on public.collections (user_id, card_id);

-- ==========================================
-- 6. user_themes (유저 보유 테마)
-- ==========================================
create table public.user_themes (
  id bigserial primary key,
  user_id uuid not null references public.users (id) on delete cascade,
  theme_id uuid not null references public.card_themes (id) on delete cascade,
  acquired_from_pack_id uuid references public.card_packs (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint uq_user_theme unique (user_id, theme_id)
);

-- ==========================================
-- 7. likes (카드 좋아요)
-- ==========================================
create table public.likes (
  user_id uuid not null references public.users (id) on delete cascade,
  card_id uuid not null references public.cards (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, card_id)
);

-- ==========================================
-- 8. token_transactions (토큰 원장)
-- ==========================================
create table public.token_transactions (
  id bigserial primary key,
  user_id uuid not null references public.users (id) on delete cascade,
  amount integer not null,
  transaction_type varchar(30) not null check (
    transaction_type in ('CHARGE', 'PREMIUM_CARD_CREATE', 'PACK_BUY', 'GRADE_REWARD')
  ),
  description text,
  created_at timestamptz not null default now()
);

create index idx_token_tx_user_id on public.token_transactions (user_id);

-- ==========================================
-- 9. reports (신고)
-- ==========================================
create table public.reports (
  id bigserial primary key,
  reporter_id uuid not null references public.users (id) on delete cascade,
  card_id uuid not null references public.cards (id) on delete cascade,
  reason varchar(50) not null check (reason in ('SPAM', 'ABUSE', 'INAPPROPRIATE')),
  details text,
  status varchar(20) not null default 'PENDING' check (
    status in ('PENDING', 'RESOLVED', 'REJECTED')
  ),
  created_at timestamptz not null default now()
);

create index idx_reports_status on public.reports (status);

-- ==========================================
-- Auth signup → public.users 동기화
-- ==========================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_provider text;
  v_social_id text;
  v_nickname text;
begin
  v_provider := upper(coalesce(
    new.raw_user_meta_data ->> 'provider',
    new.raw_app_meta_data ->> 'provider',
    'GOOGLE'
  ));

  if v_provider not in ('KAKAO', 'GOOGLE') then
    v_provider := case lower(v_provider)
      when 'kakao' then 'KAKAO'
      when 'google' then 'GOOGLE'
      else 'GOOGLE'
    end;
  end if;

  v_social_id := coalesce(
    new.raw_user_meta_data ->> 'social_id',
    new.raw_user_meta_data ->> 'sub',
    new.raw_user_meta_data ->> 'provider_id',
    new.id::text
  );

  v_nickname := coalesce(
    new.raw_user_meta_data ->> 'nickname',
    new.raw_user_meta_data ->> 'name',
    new.raw_user_meta_data ->> 'full_name',
    split_part(new.email, '@', 1),
    'user'
  );

  insert into public.users (
    id,
    email,
    nickname,
    profile_image_url,
    provider,
    social_id
  )
  values (
    new.id,
    coalesce(new.email, new.id::text || '@oauth.local'),
    left(v_nickname, 50),
    new.raw_user_meta_data ->> 'avatar_url',
    v_provider,
    v_social_id
  );

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ==========================================
-- Row Level Security
-- ==========================================
alter table public.users enable row level security;
alter table public.card_packs enable row level security;
alter table public.card_themes enable row level security;
alter table public.cards enable row level security;
alter table public.collections enable row level security;
alter table public.user_themes enable row level security;
alter table public.likes enable row level security;
alter table public.token_transactions enable row level security;
alter table public.reports enable row level security;

-- users
create policy "users_select_public"
  on public.users for select
  using (true);

create policy "users_update_own"
  on public.users for update
  using (auth.uid() = id);

-- card_packs / card_themes (상점 조회)
create policy "card_packs_select_active"
  on public.card_packs for select
  using (is_active = true);

create policy "card_themes_select_all"
  on public.card_themes for select
  using (true);

-- cards
create policy "cards_select_all"
  on public.cards for select
  using (true);

create policy "cards_insert_own"
  on public.cards for insert
  with check (auth.uid() = creator_id);

create policy "cards_update_own"
  on public.cards for update
  using (auth.uid() = creator_id);

create policy "cards_delete_own"
  on public.cards for delete
  using (auth.uid() = creator_id);

-- collections
create policy "collections_select_own"
  on public.collections for select
  using (auth.uid() = user_id);

create policy "collections_select_public_by_card"
  on public.collections for select
  using (true);

-- Note: duplicate select policies OR - Supabase merges with OR

-- user_themes
create policy "user_themes_select_own"
  on public.user_themes for select
  using (auth.uid() = user_id);

-- likes
create policy "likes_select_all"
  on public.likes for select
  using (true);

create policy "likes_insert_own"
  on public.likes for insert
  with check (auth.uid() = user_id);

create policy "likes_delete_own"
  on public.likes for delete
  using (auth.uid() = user_id);

-- token_transactions (본인 조회만, 쓰기는 service role)
create policy "token_tx_select_own"
  on public.token_transactions for select
  using (auth.uid() = user_id);

-- reports
create policy "reports_insert_own"
  on public.reports for insert
  with check (auth.uid() = reporter_id);

create policy "reports_select_own"
  on public.reports for select
  using (auth.uid() = reporter_id);
