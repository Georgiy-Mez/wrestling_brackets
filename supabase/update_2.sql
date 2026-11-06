-- Обновление: веса из приложения, без пола и телефона.
-- Supabase → SQL Editor → New query → вставить → Run (один раз)
alter table tournaments add column if not exists age_groups jsonb;
alter table entries add column if not exists weight_cat text;
alter table entries alter column gender drop not null;
