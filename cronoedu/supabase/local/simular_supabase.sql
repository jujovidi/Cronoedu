-- Solo para probar el esquema en un PostgreSQL normal (por ejemplo, el del PC).
-- Crea lo mínimo que Supabase ya trae: los roles anon y authenticated, la
-- tabla auth.users y la función auth.uid(). En Supabase NO se ejecuta.
--
-- Para "iniciar sesión" como un usuario en las pruebas:
--   set role authenticated;
--   select set_config('request.jwt.claim.sub', '<uuid del usuario>', false);

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
end $$;

create schema if not exists auth;
grant usage on schema auth, public to anon, authenticated;

create table if not exists auth.users (
  id                 uuid primary key default gen_random_uuid(),
  email              text unique,
  raw_user_meta_data jsonb not null default '{}',
  created_at         timestamptz not null default now()
);

create or replace function auth.uid() returns uuid
language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

grant execute on function auth.uid() to anon, authenticated;
