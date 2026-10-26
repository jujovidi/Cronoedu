import 'dart:io';

import 'package:cronoedu/models/schedule_block.dart';
import 'package:cronoedu/services/pdf_schedule_importer.dart';
import 'package:cronoedu/services/schedule_pdf_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures_reporte_horario.dart';

void main() {
  void expectSample(List<ParsedClass> classes) {
    for (final c in classes) {
      // ignore: avoid_print
      print(c);
    }
    expect(classes, hasLength(10));

    final gerencia = classes.firstWhere((c) => c.title == 'Gerencia de Proyectos');
    expect(gerencia.weekday, 1);
    expect(gerencia.start, const DayTime(11, 0));
    expect(gerencia.end, const DayTime(13, 0));
    expect(gerencia.room, 'E-204');
    expect(gerencia.teacher, 'Oscar David Suarez Torres');

    final modelacion = classes.firstWhere((c) => c.title == 'Modelacion');
    expect(modelacion.weekday, 4);
    expect(modelacion.end, const DayTime(14, 0));

    final opcion = classes.firstWhere((c) => c.title == 'Opcion de Grado');
    expect(opcion.weekday, 1);
    expect(opcion.start, const DayTime(9, 0));

    final giti = classes.where((c) => c.title == 'Gestión de Infraestructuras de TI');
    expect(giti.single.weekday, 5);
    expect(giti.single.group, contains('Profundizacion II'));

    final wan = classes.where((c) => c.title == 'Redes WAN Definidas por Software').toList();
    expect(wan.map((c) => c.weekday), [4, 4]);
    expect(wan.map((c) => c.room).toSet(), {'F-205', 'F-302'});

    final seguridad = classes.firstWhere((c) => c.title == 'Seguridad Perimetral');
    expect(seguridad.weekday, 6);
    expect(seguridad.room, 'F-207');
  }

  test('reconoce el reporteHorario por posiciones', () {
    expectSample(SchedulePdfParser().parse(reporteHorarioWords));
  });

  test('importa el PDF real con Syncfusion', () {
    final bytes = File('test/reporteHorario_ejemplo.pdf').readAsBytesSync();
    expectSample(PdfScheduleImporter().importBytes(bytes));
  });

  test('rechaza un documento sin tabla de horario', () {
    expect(
      () => SchedulePdfParser().parse(const [PdfWord('Hola', 0, 0, 10, 10)]),
      throwsA(isA<ScheduleParseException>()),
    );
  });
}
