-- Crea desde cero la base cronoedu_pruebas en el PostgreSQL del PC, carga el
-- esquema y el catálogo, y corre las pruebas. Desde la carpeta cronoedu:
--   & "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -f supabase/local/probar_todo.sql
\set ON_ERROR_STOP on
\set QUIET on
set client_min_messages = warning;

drop database if exists cronoedu_pruebas;
create database cronoedu_pruebas encoding 'UTF8' template template0;
\c cronoedu_pruebas
-- Los archivos están en UTF-8 (la consola de Windows usa otra codificación).
\encoding UTF8

\ir simular_supabase.sql
\ir ../migrations/0001_esquema.sql
\ir ../seed.sql
\echo 'Esquema y catálogo cargados.'

set client_min_messages = notice;
\ir pruebas.sql
