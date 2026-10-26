-- Sube el esquema y el catálogo a la base de Supabase y muestra un resumen.
-- Solo para una base nueva (el esquema no se puede crear dos veces). Para
-- actualizar solo el catálogo, ejecutar seed.sql. Desde la carpeta cronoedu:
--   & "C:\Program Files\PostgreSQL\18\bin\psql.exe" "host=<host del Session pooler> port=5432 user=postgres.<ref> dbname=postgres sslmode=require" -f supabase/subir.sql
\set ON_ERROR_STOP on
\set QUIET on
\encoding UTF8
set client_min_messages = warning;

\ir migrations/0001_esquema.sql
\echo 'Esquema creado.'
\ir seed.sql
\echo 'Catálogo cargado.'

\set QUIET off
select (select count(*) from public.materiales)         as materiales,
       (select count(*) from public.material_programas) as programas,
       (select count(*) from public.sinonimos)          as sinonimos,
       (select count(*) from public.objetos_avatar)     as objetos_avatar,
       (select version from public.catalogo_version)    as version_catalogo;
