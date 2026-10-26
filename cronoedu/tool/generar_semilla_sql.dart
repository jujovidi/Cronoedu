// Genera supabase/seed.sql: el catálogo de material de estudio (desde
// assets/data/material_estudio.json.gz) y los objetos de la tienda del avatar
// (desde AvatarCatalog), para cargarlos en la base de datos.
//
// Uso (desde la carpeta cronoedu):
//   dart run tool/generar_semilla_sql.dart
//
// Se puede ejecutar las veces que haga falta: el catálogo se reemplaza
// completo y los objetos del avatar se actualizan sin borrar las compras.
import 'dart:convert';
import 'dart:io';

import 'package:cronoedu/models/avatar.dart';

void main() {
  final catalogo =
      jsonDecode(utf8.decode(gzip.decode(File('assets/data/material_estudio.json.gz').readAsBytesSync())))
          as Map<String, dynamic>;
  final materiales = (catalogo['materiales'] as List).cast<Map<String, dynamic>>();
  final sinonimos = (catalogo['sinonimos'] as Map<String, dynamic>).cast<String, List<dynamic>>();
  final stopwords = (catalogo['stopwords'] as List).cast<String>();

  final sql = StringBuffer()
    ..writeln('-- Generado por tool/generar_semilla_sql.dart. No editar a mano.')
    ..writeln("set client_encoding = 'UTF8';")
    ..writeln('begin;')
    ..writeln()
    ..writeln('truncate public.material_programas, public.materiales, public.sinonimos, public.stopwords;')
    ..writeln();

  _insert(
    sql,
    'insert into public.materiales (id, fuente, tipo, titulo, autores, anio, subcategoria, url, '
    'url_requiere_base, idx_titulo, idx_temas, idx_resumen)',
    [
      for (final m in materiales)
        '${_txt(m['id'])}, ${_txt(m['fuente'])}, ${_txt(m['tipo'] ?? '')}, ${_txt(m['titulo'])}, '
            '${_arr(m['autores'])}, ${m['anio'] ?? 'null'}, ${_txt(m['subcategoria'])}, ${_txt(m['url'])}, '
            '${m['url_requiere_base'] == true}, ${_txt(m['idx_titulo'] ?? '')}, ${_txt(m['idx_temas'] ?? '')}, '
            '${_txt(m['idx_resumen'] ?? '')}',
    ],
  );
  _insert(sql, 'insert into public.material_programas', [
    for (final m in materiales)
      for (final p in {...?(m['programas'] as List?)?.cast<String>()}) '${_txt(m['id'])}, ${_txt(p)}',
  ]);
  _insert(sql, 'insert into public.sinonimos', [for (final e in sinonimos.entries) '${_txt(e.key)}, ${_arr(e.value)}']);
  _insert(sql, 'insert into public.stopwords', [for (final s in stopwords.toSet()) _txt(s)]);
  sql
    ..writeln(
      'insert into public.catalogo_version (version) values (${_txt(catalogo['version'])}) '
      'on conflict (id) do update set version = excluded.version, actualizado = now();',
    )
    ..writeln();
  _insert(
    sql,
    'insert into public.objetos_avatar',
    [
      for (final o in AvatarCatalog.items)
        '${_txt(o.id)}, ${_txt(o.name)}, ${_txt(o.slot.name)}, ${o.price}, ${o.level}',
    ],
    tail:
        ' on conflict (id) do update set nombre = excluded.nombre, ranura = excluded.ranura, '
        'precio = excluded.precio, nivel = excluded.nivel',
  );
  sql.writeln('commit;');

  File('supabase/seed.sql').writeAsStringSync(sql.toString());
  stdout.writeln(
    '${materiales.length} materiales y ${AvatarCatalog.items.length} objetos del avatar en supabase/seed.sql',
  );
}

/// Escribe [rows] en inserts de hasta 200 filas: contra Supabase cada
/// sentencia es un viaje por internet, y una por fila tarda minutos.
void _insert(StringBuffer sql, String head, List<String> rows, {String tail = ''}) {
  for (var i = 0; i < rows.length; i += 200) {
    final chunk = rows.sublist(i, i + 200 > rows.length ? rows.length : i + 200);
    sql
      ..writeln('$head values')
      ..writeln(chunk.map((r) => '  ($r)').join(',\n'))
      ..writeln('$tail;')
      ..writeln();
  }
}

String _txt(Object? v) => v == null ? 'null' : "'${v.toString().replaceAll("'", "''")}'";

String _arr(Object? v) {
  final items = (v as List?) ?? const [];
  return items.isEmpty ? "'{}'::text[]" : 'array[${items.map(_txt).join(', ')}]::text[]';
}
