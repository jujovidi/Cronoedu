"""Genera assets/data/material_estudio.json.gz a partir de la base unificada.

Uso (desde la carpeta cronoedu):
    python3 tool/compactar_material.py RUTA/material_estudio.json RUTA/sinonimos.json

Deja solo los campos que usa la app y une los sinónimos en el mismo archivo.
"""
import gzip
import json
import sys

CAMPOS = ['id', 'fuente', 'tipo', 'titulo', 'autores', 'anio', 'programas', 'subcategoria',
          'url', 'url_requiere_base', 'idx_titulo', 'idx_temas', 'idx_resumen']

catalogo = json.load(open(sys.argv[1], encoding='utf-8'))
sinonimos = json.load(open(sys.argv[2], encoding='utf-8'))
compacto = {
    'version': catalogo['version'],
    'stopwords': catalogo['stopwords'],
    'sinonimos': {k: v for k, v in sinonimos.items() if not k.startswith('_')},
    'materiales': [{k: m[k] for k in CAMPOS if m.get(k) not in (None, '', [], False)} for m in catalogo['materiales']],
}
datos = json.dumps(compacto, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
with open('assets/data/material_estudio.json.gz', 'wb') as f:
    f.write(gzip.compress(datos, 9, mtime=0))
print(f"{len(compacto['materiales'])} materiales, {len(datos) // 1024} KB sin comprimir, "
      f"{len(gzip.compress(datos, 9)) // 1024} KB comprimido")
