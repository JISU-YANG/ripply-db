-- 초기 카드팩 / 테마 시드 데이터

-- ==========================================
-- 기본 무료 테마 (카드팩 없음)
-- ==========================================
insert into public.card_themes (theme_code, name, is_premium, preview_image_url)
values
  ('BASIC_WHITE', '기본 화이트', false, null),
  ('BASIC_DARK', '기본 다크', false, null)
on conflict (theme_code) do nothing;

-- ==========================================
-- Midnight Pack (프리미엄)
-- ==========================================
insert into public.card_packs (id, title, description, price_tokens, max_supply, is_active)
values (
  'a1000000-0000-4000-8000-000000000001',
  'Midnight Pack',
  '깊은 밤을 닮은 프리미엄 카드 테마 모음',
  500,
  null,
  true
)
on conflict (id) do nothing;

insert into public.card_themes (card_pack_id, theme_code, name, is_premium, preview_image_url)
values
  (
    'a1000000-0000-4000-8000-000000000001',
    'MIDNIGHT_BLUE',
    '미드나잇 블루',
    true,
    null
  ),
  (
    'a1000000-0000-4000-8000-000000000001',
    'MIDNIGHT_GOLD',
    '미드나잇 골드',
    true,
    null
  )
on conflict (theme_code) do nothing;

-- ==========================================
-- Dawn Pack (프리미엄)
-- ==========================================
insert into public.card_packs (id, title, description, price_tokens, max_supply, is_active)
values (
  'a1000000-0000-4000-8000-000000000002',
  'Dawn Pack',
  '새벽빛을 담은 따뜻한 프리미엄 테마',
  300,
  1000,
  true
)
on conflict (id) do nothing;

insert into public.card_themes (card_pack_id, theme_code, name, is_premium, preview_image_url)
values
  (
    'a1000000-0000-4000-8000-000000000002',
    'DAWN_PINK',
    '던 핑크',
    true,
    null
  ),
  (
    'a1000000-0000-4000-8000-000000000002',
    'DAWN_PEACH',
    '던 피치',
    true,
    null
  )
on conflict (theme_code) do nothing;
