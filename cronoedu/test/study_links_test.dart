import 'package:cronoedu/models/task.dart';
import 'package:cronoedu/services/study_links.dart';
import 'package:flutter_test/flutter_test.dart';

Task _task(String subject, String topic) =>
    Task(id: 't', subject: subject, topic: topic, dueDate: DateTime(2026, 11, 2), complexity: TaskComplexity.tareita);

void main() {
  test('la búsqueda quita el tipo de entrega y los números', () {
    expect(StudyLinks.query(_task('Modelación', 'Taller 3')), 'Modelación');
    expect(
      StudyLinks.query(_task('Seguridad Perimetral', 'Diseño de firewall')),
      'Seguridad Perimetral Diseño de firewall',
    );
    expect(StudyLinks.query(_task('Cálculo', 'Parcial 2 corte')), 'Cálculo');
  });

  test('da 2 videos y 3 artículos con enlaces https', () {
    final links = StudyLinks.forTask(_task('Redes Convergentes', 'VoIP'));
    expect(links.where((l) => l.kind == StudyLinkKind.video), hasLength(2));
    expect(links.where((l) => l.kind == StudyLinkKind.articulo), hasLength(3));
    expect(links.every((l) => l.url.scheme == 'https'), isTrue);
    expect(links.first.url.toString(), contains('youtube.com/results?search_query=Redes+Convergentes+VoIP'));
  });
}
