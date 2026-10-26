-- Esquema de CronoEdu para Supabase (PostgreSQL 15 o superior).
--
-- Dos partes en la misma base:
--   1. Catálogo de material de estudio (metadata de las bibliotecas de la
--      universidad) para las recomendaciones. Lo leen todos; solo se carga
--      desde el servidor con supabase/seed.sql.
--   2. Cuentas y gamificación: perfil, bellotas, tienda del avatar y ranking.
--      El inicio de sesión lo maneja Supabase Auth (tabla auth.users); aquí
--      solo vive lo propio de CronoEdu.
--
-- La app nunca escribe bellotas directamente: llama a las funciones
-- ganar_enfoque, ganar_ciclo, ganar_tarea y comprar_objeto, que aplican las
-- mismas reglas de lib/services/rewards.dart. Así nadie se sube puntos a mano.
--
-- Las fechas ("hoy", "esta semana") se cuentan en hora de Colombia.

set client_encoding = 'UTF8';

-- ---------------------------------------------------------------------------
-- 1. Catálogo de material de estudio
-- ---------------------------------------------------------------------------

create table public.materiales (
  id                text primary key,
  fuente            text not null,                -- ENI, AlphaCloud, Eureka, BioAtlas, BioAtlasVet
  tipo              text not null default '',      -- libro, atlas, ...
  titulo            text not null,
  autores           text[] not null default '{}',
  anio              smallint,
  subcategoria      text,
  url               text,
  url_requiere_base boolean not null default false, -- las de ENI traen %SITE_CLIENT%
  -- Tokens normalizados para la búsqueda (los mismos que usa la app).
  idx_titulo        text not null default '',
  idx_temas         text not null default '',
  idx_resumen       text not null default ''
);

-- Carreras para las que sirve cada material (sube un 30 % en la búsqueda).
create table public.material_programas (
  material_id text not null references public.materiales on delete cascade,
  programa    text not null,
  primary key (material_id, programa)
);
create index material_programas_programa on public.material_programas (programa);

create table public.sinonimos (
  palabra      text primary key,
  equivalentes text[] not null
);

create table public.stopwords (
  palabra text primary key
);

-- Versión del catálogo: la app la compara con la de su copia local para
-- saber si debe descargarlo de nuevo.
create table public.catalogo_version (
  id          boolean primary key default true check (id),
  version     text not null,
  actualizado timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. Cuentas y gamificación
-- ---------------------------------------------------------------------------

create or replace function public.hoy_colombia() returns date
language sql stable as $$ select (now() at time zone 'America/Bogota')::date $$;

-- Lunes de la semana actual (igual que currentWeekKey() en la app).
create or replace function public.lunes_colombia() returns date
language sql stable as $$ select date_trunc('week', now() at time zone 'America/Bogota')::date $$;

-- Objetos de la tienda del avatar (copia de AvatarCatalog, la carga seed.sql).
create table public.objetos_avatar (
  id     text primary key,
  nombre text not null,
  ranura text not null check (ranura in ('animal', 'cabeza', 'cara', 'efecto', 'fondo')),
  precio int not null default 0 check (precio >= 0),
  nivel  int not null default 1 check (nivel >= 1)
);

create table public.perfiles (
  id               uuid primary key references auth.users on delete cascade,
  nickname         text not null check (nickname ~ '^[A-Za-z0-9_.]{3,15}$'),
  nombre           text not null default '',
  carrera          text not null default '',
  semestre         smallint not null default 1 check (semestre between 1 and 12),
  avatar           jsonb not null default '{"animal": "mapache", "fondo": "lavanda"}',
  racha            int not null default 0,
  ultimo_dia_racha date,
  creado           timestamptz not null default now()
);
-- Único sin importar mayúsculas, como en LocalAuthRepository.
create unique index perfiles_nickname_unico on public.perfiles (lower(nickname));

create table public.objetos_comprados (
  usuario_id uuid not null references public.perfiles on delete cascade,
  objeto_id  text not null references public.objetos_avatar,
  comprado   timestamptz not null default now(),
  primary key (usuario_id, objeto_id)
);

create type public.motivo_bellotas as enum ('enfoque', 'ciclo', 'racha', 'tarea', 'tarea_a_tiempo', 'compra');

-- Cada bellota ganada (cantidad > 0) o gastada (< 0). El saldo, el nivel y el
-- ranking salen de sumar esta tabla.
create table public.movimientos_bellotas (
  id         bigint generated always as identity primary key,
  usuario_id uuid not null references public.perfiles on delete cascade,
  cantidad   int not null check (cantidad <> 0),
  motivo     public.motivo_bellotas not null,
  -- tarea: id de la tarea; ciclo/racha: id del movimiento de enfoque;
  -- compra: id del objeto.
  referencia text,
  minutos    smallint,                             -- solo en 'enfoque'
  creado     timestamptz not null default now()
);
create index movimientos_usuario_fecha on public.movimientos_bellotas (usuario_id, creado);
-- Cada tarea paga una sola vez y cada enfoque cierra un solo ciclo.
create unique index movimientos_una_vez on public.movimientos_bellotas (usuario_id, motivo, referencia)
  where motivo in ('tarea', 'tarea_a_tiempo', 'ciclo', 'racha');

-- Saldo y nivel de cada usuario (nivel = 1 + ganadas / 120, como Rewards.levelFor).
create view public.saldos with (security_invoker = true) as
select p.id as usuario_id,
       coalesce(sum(m.cantidad), 0)::int                              as bellotas,
       coalesce(sum(m.cantidad) filter (where m.cantidad > 0), 0)::int as ganadas,
       1 + coalesce(sum(m.cantidad) filter (where m.cantidad > 0), 0)::int / 120 as nivel
from public.perfiles p
left join public.movimientos_bellotas m on m.usuario_id = p.id
group by p.id;

-- Ranking. Estas vistas corren con los permisos de su dueño a propósito: así
-- cualquiera ve nickname, avatar y puntos de todos, pero no el resto del perfil.
-- Los puntos son las bellotas ganadas (gastar no resta).
create view public.ranking_total as
select p.id as usuario_id, p.nickname, p.avatar,
       coalesce(sum(m.cantidad) filter (where m.cantidad > 0), 0)::int as puntos
from public.perfiles p
left join public.movimientos_bellotas m on m.usuario_id = p.id
group by p.id
order by puntos desc, lower(p.nickname);

create view public.ranking_semanal as
select p.id as usuario_id, p.nickname, p.avatar,
       coalesce(sum(m.cantidad) filter (
         where m.cantidad > 0 and m.creado >= public.lunes_colombia()::timestamp at time zone 'America/Bogota'
       ), 0)::int as puntos
from public.perfiles p
left join public.movimientos_bellotas m on m.usuario_id = p.id
group by p.id
order by puntos desc, lower(p.nickname);

-- ---------------------------------------------------------------------------
-- Registro: el perfil se crea solo al crear la cuenta en Supabase Auth.
-- La app manda el nickname en los metadatos: signUp(data: {'nickname': ...}).
-- ---------------------------------------------------------------------------

create or replace function public.crear_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfiles (id, nickname) values (new.id, trim(new.raw_user_meta_data ->> 'nickname'));
  return new;
end $$;

create trigger al_crear_usuario after insert on auth.users
  for each row execute function public.crear_perfil();

-- Para la pantalla de registro (se puede llamar sin sesión).
create or replace function public.nickname_disponible(p_nickname text) returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (select 1 from public.perfiles where lower(nickname) = lower(trim(p_nickname)))
$$;

-- El avatar solo puede llevar objetos gratis o comprados.
create or replace function public.validar_avatar() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_ranura text;
  v_id     text;
begin
  for v_ranura, v_id in select key, value from jsonb_each_text(new.avatar) loop
    if not exists (
      select 1 from public.objetos_avatar o
      where o.id = v_id and o.ranura = v_ranura
        and ((o.precio = 0 and o.nivel <= 1)
             or exists (select 1 from public.objetos_comprados c where c.usuario_id = new.id and c.objeto_id = o.id))
    ) then
      raise exception 'No tienes el objeto % para %', v_id, v_ranura;
    end if;
  end loop;
  return new;
end $$;

create trigger validar_avatar before insert or update of avatar on public.perfiles
  for each row execute function public.validar_avatar();

-- ---------------------------------------------------------------------------
-- Funciones para ganar y gastar bellotas (las llama la app con rpc()).
-- Devuelven lo ganado para mostrarlo en pantalla.
-- ---------------------------------------------------------------------------

-- Fin de un enfoque: 1 bellota por cada 5 min. Tope de 16 h de enfoque al día.
create or replace function public.ganar_enfoque(p_minutos int) returns int
language plpgsql security definer set search_path = public as $$
declare
  v_usuario uuid := auth.uid();
  v_hoy     int;
  v_ganadas int := p_minutos / 5;
begin
  if v_usuario is null then raise exception 'Sin sesión'; end if;
  if p_minutos not between 1 and 600 then raise exception 'Minutos fuera de rango'; end if;
  select coalesce(sum(minutos), 0) into v_hoy from public.movimientos_bellotas
   where usuario_id = v_usuario and motivo = 'enfoque'
     and creado >= public.hoy_colombia()::timestamp at time zone 'America/Bogota';
  if v_hoy + p_minutos > 960 then raise exception 'Superaste el tope de enfoque de hoy'; end if;
  -- Menos de 5 min no da bellotas ni cuenta para el ciclo (pide 10).
  if v_ganadas = 0 then return 0; end if;
  insert into public.movimientos_bellotas (usuario_id, cantidad, motivo, minutos)
  values (v_usuario, v_ganadas, 'enfoque', p_minutos);
  return v_ganadas;
end $$;

-- Fin del descanso: 10 bellotas si el último enfoque (de las últimas 4 h)
-- duró al menos 10 min, más el bono de racha en el primer ciclo del día.
create or replace function public.ganar_ciclo() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_usuario uuid := auth.uid();
  v_enfoque bigint;
  v_hoy     date := public.hoy_colombia();
  v_perfil  public.perfiles;
  v_bono    int := 0;
begin
  if v_usuario is null then raise exception 'Sin sesión'; end if;
  select e.id into v_enfoque from public.movimientos_bellotas e
   where e.usuario_id = v_usuario and e.motivo = 'enfoque' and e.minutos >= 10 and e.creado > now() - interval '4 hours'
     and not exists (select 1 from public.movimientos_bellotas c
                      where c.usuario_id = v_usuario and c.motivo = 'ciclo' and c.referencia = e.id::text)
   order by e.creado desc limit 1;
  if v_enfoque is null then return jsonb_build_object('bellotas', 0, 'bono_racha', 0); end if;

  insert into public.movimientos_bellotas (usuario_id, cantidad, motivo, referencia)
  values (v_usuario, 10, 'ciclo', v_enfoque::text);

  select * into v_perfil from public.perfiles where id = v_usuario for update;
  if v_perfil.ultimo_dia_racha is distinct from v_hoy then
    v_perfil.racha := case when v_perfil.ultimo_dia_racha = v_hoy - 1 then v_perfil.racha + 1 else 1 end;
    update public.perfiles set racha = v_perfil.racha, ultimo_dia_racha = v_hoy where id = v_usuario;
    v_bono := least(v_perfil.racha * 5, 25);
    insert into public.movimientos_bellotas (usuario_id, cantidad, motivo, referencia)
    values (v_usuario, v_bono, 'racha', v_enfoque::text);
  end if;
  return jsonb_build_object('bellotas', 10, 'bono_racha', v_bono);
end $$;

-- Tarea completada: 15, y 10 más si es a tiempo. Cada tarea paga una vez.
create or replace function public.ganar_tarea(p_tarea_id text, p_a_tiempo boolean) returns int
language plpgsql security definer set search_path = public as $$
declare
  v_usuario uuid := auth.uid();
begin
  if v_usuario is null then raise exception 'Sin sesión'; end if;
  insert into public.movimientos_bellotas (usuario_id, cantidad, motivo, referencia)
  values (v_usuario, 15, 'tarea', p_tarea_id)
  on conflict do nothing;
  if not found then return 0; end if;
  if p_a_tiempo then
    insert into public.movimientos_bellotas (usuario_id, cantidad, motivo, referencia)
    values (v_usuario, 10, 'tarea_a_tiempo', p_tarea_id);
    return 25;
  end if;
  return 15;
end $$;

-- Compra un objeto si hay bellotas y nivel suficientes. Devuelve el saldo nuevo.
create or replace function public.comprar_objeto(p_objeto text) returns int
language plpgsql security definer set search_path = public as $$
declare
  v_usuario uuid := auth.uid();
  v_objeto  public.objetos_avatar;
  v_saldo   public.saldos;
begin
  if v_usuario is null then raise exception 'Sin sesión'; end if;
  perform 1 from public.perfiles where id = v_usuario for update; -- evita dos compras a la vez
  select * into v_objeto from public.objetos_avatar where id = p_objeto;
  if not found then raise exception 'Ese objeto no existe'; end if;
  if exists (select 1 from public.objetos_comprados where usuario_id = v_usuario and objeto_id = p_objeto) then
    raise exception 'Ya tienes ese objeto';
  end if;
  select * into v_saldo from public.saldos where usuario_id = v_usuario;
  if v_saldo.nivel < v_objeto.nivel then raise exception 'Necesitas nivel %', v_objeto.nivel; end if;
  if v_saldo.bellotas < v_objeto.precio then raise exception 'No te alcanzan las bellotas'; end if;
  if v_objeto.precio > 0 then
    insert into public.movimientos_bellotas (usuario_id, cantidad, motivo, referencia)
    values (v_usuario, -v_objeto.precio, 'compra', p_objeto);
  end if;
  insert into public.objetos_comprados (usuario_id, objeto_id) values (v_usuario, p_objeto);
  return v_saldo.bellotas - v_objeto.precio;
end $$;

-- Todo lo del estudiante en una sola llamada (al abrir la app y después de
-- cada acción con bellotas).
create or replace function public.mi_estado() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'nickname', p.nickname, 'nombre', p.nombre, 'carrera', p.carrera, 'semestre', p.semestre,
    'avatar', p.avatar, 'racha', p.racha, 'ultimo_dia_racha', p.ultimo_dia_racha,
    'bellotas', s.bellotas, 'ganadas', s.ganadas,
    'puntos_semana', (select coalesce(sum(m.cantidad), 0) from public.movimientos_bellotas m
                       where m.usuario_id = p.id and m.cantidad > 0
                         and m.creado >= public.lunes_colombia()::timestamp at time zone 'America/Bogota'),
    'objetos', coalesce((select jsonb_agg(c.objeto_id) from public.objetos_comprados c where c.usuario_id = p.id), '[]'))
  from public.perfiles p
  join public.saldos s on s.usuario_id = p.id
  where p.id = auth.uid()
$$;

-- Borra la cuenta: perfil, bellotas, compras y puesto en el ranking.
create or replace function public.borrar_mi_cuenta() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Sin sesión'; end if;
  delete from auth.users where id = auth.uid();
end $$;

-- ---------------------------------------------------------------------------
-- Permisos (Row Level Security). anon = sin sesión, authenticated = con sesión.
-- ---------------------------------------------------------------------------

alter table public.materiales           enable row level security;
alter table public.material_programas   enable row level security;
alter table public.sinonimos            enable row level security;
alter table public.stopwords            enable row level security;
alter table public.catalogo_version     enable row level security;
alter table public.objetos_avatar       enable row level security;
alter table public.perfiles             enable row level security;
alter table public.objetos_comprados    enable row level security;
alter table public.movimientos_bellotas enable row level security;

-- Catálogo y tienda: lectura para todos, sin escritura desde la app.
create policy leer on public.materiales         for select using (true);
create policy leer on public.material_programas for select using (true);
create policy leer on public.sinonimos          for select using (true);
create policy leer on public.stopwords          for select using (true);
create policy leer on public.catalogo_version   for select using (true);
create policy leer on public.objetos_avatar     for select using (true);

-- Lo de cada estudiante: solo lo suyo.
create policy propio on public.perfiles             for select using (id = auth.uid());
create policy propio_editar on public.perfiles      for update using (id = auth.uid()) with check (id = auth.uid());
create policy propio on public.objetos_comprados    for select using (usuario_id = auth.uid());
create policy propio on public.movimientos_bellotas for select using (usuario_id = auth.uid());

revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

grant select on public.materiales, public.material_programas, public.sinonimos, public.stopwords,
                public.catalogo_version, public.objetos_avatar, public.ranking_total, public.ranking_semanal
  to anon, authenticated;
grant select on public.perfiles, public.objetos_comprados, public.movimientos_bellotas, public.saldos to authenticated;
-- Del perfil, la app solo cambia esto (racha y nickname los maneja el servidor).
grant update (nombre, carrera, semestre, avatar) on public.perfiles to authenticated;

grant execute on function public.nickname_disponible(text) to anon, authenticated;
grant execute on function public.hoy_colombia(), public.lunes_colombia() to anon, authenticated;
grant execute on function public.ganar_enfoque(int), public.ganar_ciclo(), public.ganar_tarea(text, boolean),
                          public.comprar_objeto(text), public.mi_estado(), public.borrar_mi_cuenta() to authenticated;
