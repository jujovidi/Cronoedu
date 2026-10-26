import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'schedule_pdf_parser.dart';

/// Extrae las palabras (con posición) del PDF y las pasa al parser.
class PdfScheduleImporter {
  List<ParsedClass> importBytes(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final lines = PdfTextExtractor(document).extractTextLines();
      final words = <PdfWord>[];
      for (final line in lines) {
        for (final w in line.wordCollection) {
          final b = w.bounds;
          // Cada página se apila debajo de la anterior.
          final offset = line.pageIndex * 10000.0;
          words.add(PdfWord(w.text.trim(), b.left, b.top + offset, b.right, b.bottom + offset));
        }
      }
      return SchedulePdfParser().parse(words);
    } finally {
      document.dispose();
    }
  }
}
