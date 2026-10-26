-- Pruebas del esquema con dos estudiantes de prueba. Cada bloque falla con
-- "FALLÓ: ..." si algo no se comporta como se espera.

set client_encoding = 'UTF8';
create schema pruebas;

create or replace function pruebas.esperar(ok boolean, que text) returns void
language plpgsql as $$
begin
  if not coalesce(ok, false) then raise exception 'FALLÓ: %', que; end if;
  raise notice 'ok: %', que;
end $$;

-- Error que debe ocurrir (por ejemplo, una trampa bloqueada).
create or replace function pruebas.debe_fallar(sentencia text, que text) returns void
language plpgsql as $$
begin
  execute sentencia;
  raise exception 'FALLÓ: % (no dio error)', que;
exception when others then
  if sqlerrm like 'FALLÓ:%' then raise; end if;
  raise notice 'ok: % (%)', que, sqlerrm;
end $$;

grant usage on schema pruebas to anon, authenticated;
grant execute on all functions in schema pruebas to anon, authenticated;

-- Registro (lo hace Supabase Auth; aquí se simula).
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'ana@ucundinamarca.edu.co', '{"nickname": "Ana_Est"}'),
  ('00000000-0000-0000-0000-00000000000b', 'beto@ucundinamarca.edu.co', '{"nickname": "beto.ing"}');

select pruebas.esperar((select count(*) = 2 from public.perfiles), 'se crea un perfil por cada cuenta');
select pruebas.debe_fallar(
  $$insert into auth.users (email, raw_user_meta_data) values ('otra@x.co', '{"nickname": "ana_est"}')$$,
  'nickname repetido (sin importar mayúsculas)');

-- Sin sesión ---------------------------------------------------------------
set role anon;
select pruebas.esperar((select count(*) = 916 from public.materiales), 'el catálogo se lee sin sesión');
select pruebas.esperar(not public.nickname_disponible('ANA_EST'), 'nickname_disponible ve los usados');
select pruebas.esperar(public.nickname_disponible('nuevo_nick'), 'nickname_disponible ve los libres');
select pruebas.debe_fallar('select * from public.perfiles', 'sin sesión no se leen perfiles');
select pruebas.debe_fallar($$insert into public.materiales (id, fuente, titulo) values ('x', 'x', 'x')$$,
  'la app no puede escribir el catálogo');
reset role;

-- Ana estudia ----------------------------------------------------------------
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);

select pruebas.esperar(public.ganar_enfoque(25) = 5, '25 min de enfoque = 5 bellotas');
select pruebas.esperar(public.ganar_ciclo() = '{"bellotas": 10, "bono_racha": 5}', 'ciclo: 10 + racha de 1 día (5)');
select pruebas.esperar(public.ganar_ciclo() = '{"bellotas": 0, "bono_racha": 0}', 'el mismo enfoque no cierra dos ciclos');
select pruebas.esperar(public.ganar_enfoque(3) = 0, 'menos de 5 min no da bellotas');
select pruebas.esperar(public.ganar_tarea('tarea-1', true) = 25, 'tarea a tiempo = 25');
select pruebas.esperar(public.ganar_tarea('tarea-1', true) = 0, 'cada tarea paga una sola vez');
select pruebas.esperar((select bellotas = 45 and ganadas = 45 and nivel = 1 from public.saldos), 'saldo 45, nivel 1');

select pruebas.esperar(public.comprar_objeto('mono') = 15, 'compra moñito (30) y quedan 15');
select pruebas.debe_fallar($$select public.comprar_objeto('mono')$$, 'no se compra dos veces');
select pruebas.debe_fallar($$select public.comprar_objeto('gato')$$, 'el gatito pide nivel 2');
select pruebas.debe_fallar($$select public.comprar_objeto('flor')$$, 'sin bellotas no se compra');
select pruebas.esperar((select ganadas = 45 from public.saldos), 'gastar no baja las bellotas ganadas');

update public.perfiles set avatar = '{"animal": "mapache", "fondo": "lavanda", "cabeza": "mono"}', carrera = 'Ingeniería de Sistemas';
select pruebas.esperar((select avatar ->> 'cabeza' = 'mono' from public.perfiles), 'se pone lo que compró');
select pruebas.debe_fallar($$update public.perfiles set avatar = '{"animal": "panda", "fondo": "lavanda"}'$$,
  'no se pone un objeto que no compró');

-- Trampas
select pruebas.debe_fallar($$insert into public.movimientos_bellotas (usuario_id, cantidad, motivo)
  values (auth.uid(), 9999, 'tarea')$$, 'no se suman bellotas a mano');
select pruebas.debe_fallar('update public.perfiles set racha = 100', 'no se cambia la racha a mano');
select pruebas.debe_fallar($$update public.perfiles set nickname = 'otro'$$, 'el nickname no se cambia desde la app');
select pruebas.debe_fallar($$select public.ganar_enfoque(5000)$$, 'enfoque imposible rechazado');
select pruebas.esperar((select count(*) = 1 from public.perfiles), 'Ana solo ve su propio perfil');
select pruebas.esperar((select e ->> 'bellotas' = '15' and e ->> 'ganadas' = '45' and e ->> 'puntos_semana' = '45'
                               and e ->> 'racha' = '1' and e -> 'objetos' = '["mono"]' and e ->> 'carrera' = 'Ingeniería de Sistemas'
                          from public.mi_estado() e), 'mi_estado trae saldo, racha, compras y perfil');
reset role;

-- Beto -------------------------------------------------------------------
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
select pruebas.esperar(public.ganar_tarea('t-b', false) = 15, 'tarea tarde = 15');
select pruebas.esperar((select count(*) = 0 from public.movimientos_bellotas where usuario_id <> auth.uid()),
  'Beto no ve las bellotas de Ana');

-- Ranking (lo ve todo el mundo, solo nickname, avatar y puntos)
select pruebas.esperar((select array_agg(nickname order by puntos desc) = '{Ana_Est,beto.ing}' from public.ranking_total),
  'ranking total: Ana 45, Beto 15');
select pruebas.esperar((select puntos = 45 from public.ranking_semanal where nickname = 'Ana_Est'),
  'ranking semanal cuenta lo de esta semana');
reset role;

-- Lo de la semana pasada no cuenta en el semanal
update public.movimientos_bellotas set creado = creado - interval '8 days'
 where usuario_id = '00000000-0000-0000-0000-00000000000b';
select pruebas.esperar((select puntos = 0 from public.ranking_semanal where nickname = 'beto.ing'),
  'el semanal se reinicia cada lunes');
select pruebas.esperar((select puntos = 15 from public.ranking_total where nickname = 'beto.ing'),
  'el total no se reinicia');

-- Borrar la cuenta (desde la app) borra su perfil, sus bellotas y su puesto en el ranking
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
select public.borrar_mi_cuenta();
reset role;
select pruebas.esperar((select count(*) = 1 from public.ranking_total), 'cuenta borrada sale del ranking');
select pruebas.esperar((select count(*) = 0 from auth.users where email like 'beto%'), 'la cuenta de acceso también se borra');

\echo
\echo 'TODAS LAS PRUEBAS PASARON'
