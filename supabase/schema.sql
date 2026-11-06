-- Supabase → SQL Editor → New query → вставить целиком → Run

create table tournaments (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,              -- то, что в ссылке ?t=
  title text not null,
  date date,
  place text,
  age_groups jsonb,                       -- [{minAge, maxAge, weights}] из приложения
  deadline timestamptz,
  is_open boolean not null default true,
  owner uuid not null default auth.uid() references auth.users on delete cascade,
  created_at timestamptz default now()
);

create table entries (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references tournaments on delete cascade,
  club text not null check (char_length(club) between 1 and 120),
  city text check (char_length(city) <= 80),
  coach text not null check (char_length(coach) between 1 and 120),
  coach_phone text check (char_length(coach_phone) <= 30),
  full_name text not null check (char_length(full_name) between 2 and 120),
  birth_year int not null check (birth_year between 1950 and 2030),
  gender text check (gender in ('M','F')),   -- не используется
  weight numeric(5,1) not null check (weight between 10 and 200),
  weight_cat text,                           -- «57 кг», «85+ кг»
  created_at timestamptz default now()
);

create index entries_tournament_idx on entries (tournament_id);

alter table tournaments enable row level security;
alter table entries enable row level security;

-- сайт видит только открытые турниры (для формы)
create policy "public read open" on tournaments
  for select using (is_open);

-- организатор полностью управляет своими турнирами
create policy "owner manage" on tournaments
  for all to authenticated
  using (auth.uid() = owner) with check (auth.uid() = owner);

-- с сайта можно только ДОБАВИТЬ заявку в открытый турнир до дедлайна
create policy "public submit" on entries
  for insert to anon, authenticated with check (
    exists (
      select 1 from tournaments t
      where t.id = tournament_id
        and t.is_open
        and (t.deadline is null or now() < t.deadline)
    )
  );

-- читать и удалять заявки может только организатор турнира
create policy "owner entries" on entries
  for all to authenticated using (
    exists (select 1 from tournaments t where t.id = tournament_id and t.owner = auth.uid())
  );

-- новые заявки сразу прилетают в приложение
alter publication supabase_realtime add table entries;
