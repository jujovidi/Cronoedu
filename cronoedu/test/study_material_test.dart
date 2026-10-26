import 'dart:io';

import 'package:cronoedu/services/study_material_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final index = StudyMaterialIndex.fromGzip(File(StudyMaterialLibrary.asset).readAsBytesSync());

  test('el catálogo trae los 916 materiales', () {
    expect(index.materials, hasLength(916));
  });

  test('busca por materia, tema y carrera', () {
    final bd = index.forTask(
      subject: 'Bases de datos',
      topic: 'Taller 2',
      description: 'consultas SQL con joins',
      career: 'Ingeniería de Sistemas',
      limit: 3,
    );
    expect(bd, hasLength(3));
    expect(bd.map((r) => r.material.title.toLowerCase()).where((t) => t.contains('sql')), isNotEmpty);

    final perro = index.search('Anatomía del perro', program: 'Veterinaria', limit: 3);
    expect(perro.first.material.source, contains('BioAtlasVet'));
  });

  test('los sinónimos ayudan: marketing encuentra mercadeo o publicidad', () {
    final r = index.search('marketing digital', limit: 3);
    expect(r, isNotEmpty);
  });

  test('los libros de ENI no tienen enlace hasta tener la URL de la biblioteca', () {
    final eni = index.materials.firstWhere((m) => m.id.startsWith('eni:'));
    expect(eni.url(eniBaseUrl: StudyMaterialLibrary.eniBaseUrl), isNull);
    expect(eni.url(eniBaseUrl: 'https://biblioteca.ejemplo'), startsWith('https://biblioteca.ejemplo/'));
    final alpha = index.materials.firstWhere((m) => m.id.startsWith('alpha:'));
    expect(alpha.url(), startsWith('https://'));
  });

  test('da los mismos resultados que la prueba de Python (buscar.py)', () {
    String top(String q, [String? p]) => index.search(q, program: p, limit: 1).first.material.id;
    expect(top('Anatomía del perro', 'Veterinaria'), 'bioatlasvet:7');
    expect(top('parcial de fisiología del ejercicio'), 'eureka:9788491103547');
    expect(top('taller de bases de datos SQL', 'Ingeniería de Sistemas'), 'eni:RIT12CORA');
    expect(top('Python para análisis de datos'), 'eni:EITPYTDATA');
    expect(top('Matemáticas financieras', 'Contaduría'), 'alpha:36');
  });
}
