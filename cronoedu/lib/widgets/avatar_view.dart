import 'package:flutter/material.dart';

import '../models/avatar.dart';

/// Gestos del avatar. Algunos efectos ponen el suyo (En llamas → grito).
enum AvatarMood { normal, feliz, dormido, grito, concentrado, comiendo }

/// Objetos que la mascota puede tener en las manos (pantalla de Técnicas).
enum SpriteProp { ninguno, tomate, libro }

/// Avatar en pixel art (32 × 32) estilo stickers tiernos: el animal, su
/// disfraz o gorro, algo en la cara, un efecto y el fondo cuadriculado.
/// Se dibuja en código para que cualquier extra sirva en cualquier animal.
class AvatarView extends StatelessWidget {
  const AvatarView(this.look, {super.key, this.size = 96, this.background = true, this.mood = AvatarMood.normal});

  final AvatarLook look;
  final double size;

  /// Con fondo se dibuja como sticker de esquinas redondeadas; sin fondo,
  /// solo el personaje (así se usa la mascota).
  final bool background;
  final AvatarMood mood;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Avatar: ${AvatarCatalog.byId(look.animal)?.name ?? ''}',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _AvatarPainter(look, mood, background)),
    ),
  );
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.look, this.mood, this.background);

  final AvatarLook look;
  final AvatarMood mood;
  final bool background;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    final cell = side / PixelSprite.n;
    if (background) {
      final rrect = RRect.fromRectAndRadius(Offset.zero & Size.square(side), Radius.circular(side * .22));
      canvas.clipRRect(rrect);
      final bg = _backgrounds[look.fondo] ?? _backgrounds['lavanda']!;
      canvas.drawRect(Offset.zero & Size.square(side), Paint()..color = Color(bg));
      final line = Paint()
        ..color = (look.fondo == 'noche' ? Colors.white : Colors.black).withValues(
          alpha: look.fondo == 'cuadricula' ? .09 : .05,
        )
        ..strokeWidth = side < 60 ? .5 : 1;
      for (var i = 1; i < PixelSprite.n; i++) {
        canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, side), line);
        canvas.drawLine(Offset(0, i * cell), Offset(side, i * cell), line);
      }
      if (look.fondo == 'noche') {
        final star = Paint()..color = const Color(0xFFFFE08A);
        for (final (x, y) in const [(3, 3), (27, 2), (29, 14), (2, 16), (24, 7), (6, 27)]) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), star);
        }
      }
    }
    final px = PixelSprite.build(look, mood);
    final paint = Paint()..isAntiAlias = false;
    // Un poquito más grande que la celda para que no se vean rayas entre píxeles.
    final overlap = cell * .04;
    for (var y = 0; y < PixelSprite.n; y++) {
      for (var x = 0; x < PixelSprite.n; x++) {
        final c = px[y * PixelSprite.n + x];
        if (c == 0) continue;
        paint.color = Color(c);
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell + overlap, cell + overlap), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter old) => old.look != look || old.mood != mood || old.background != background;
}

/// Dibuja una cuadrícula de píxeles de [width] × 32 (escenas de la mascota).
class PixelArt extends StatelessWidget {
  const PixelArt(this.pixels, {super.key, this.width = PixelSprite.n, this.size = 96, this.label});

  final List<int> pixels;
  final int width;

  /// Alto en pantalla; el ancho sale de la proporción.
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: label != null,
    child: SizedBox(
      width: size * width / PixelSprite.n,
      height: size,
      child: CustomPaint(painter: _PixelPainter(pixels, width)),
    ),
  );
}

class _PixelPainter extends CustomPainter {
  _PixelPainter(this.px, this.w);
  final List<int> px;
  final int w;

  @override
  void paint(Canvas canvas, Size size) {
    const h = PixelSprite.n;
    final cell = size.height / h;
    final paint = Paint()..isAntiAlias = false;
    final overlap = cell * .04;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final c = px[y * w + x];
        if (c == 0) continue;
        paint.color = Color(c);
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell + overlap, cell + overlap), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) => !identical(old.px, px) || old.w != w;
}

const _backgrounds = <String, int>{
  'lavanda': 0xFFEDE8FF,
  'cuadricula': 0xFFF8F4EA,
  'rosa': 0xFFFFE4EC,
  'menta': 0xFFDDF5E8,
  'cielo': 0xFFDDEBFF,
  'noche': 0xFF2E2A55,
};

// ---------------------------------------------------------------------------
// Sprites
// ---------------------------------------------------------------------------

typedef _Mask = bool Function(int x, int y);

const _ink = 0xFF2B2433;
const _white = 0xFFFFFFFF;
const _blush = 0xFFFF9EB1;
const _pinkNose = 0xFFF28CA0;
const _orange = 0xFFFF9A3C;

enum _Ear { pointy, round, small, none }

enum _Tail { rings, striped, plain, curl, thin, stub, duck, none }

class _Animal {
  const _Animal({
    required this.fur,
    this.body,
    this.belly,
    this.dark = _ink,
    this.ear = _Ear.pointy,
    this.innerEar = 0xFFF7B3C2,
    this.earColor,
    this.nose = _ink,
    this.feet,
    this.tail = _Tail.plain,
    this.whiskers = false,
  });

  final int fur;
  final int? body;
  final int? belly;
  final int dark;
  final _Ear ear;
  final int innerEar;
  final int? earColor;
  final int nose;
  final int? feet;
  final _Tail tail;
  final bool whiskers;
}

const _animals = <String, _Animal>{
  'mapache': _Animal(
    fur: 0xFFA09DAB,
    belly: 0xFFEFEDF3,
    dark: 0xFF67627A,
    innerEar: 0xFFEFEDF3,
    feet: 0xFF67627A,
    tail: _Tail.rings,
  ),
  'gato': _Animal(
    fur: 0xFFFBE3C4,
    belly: 0xFFFFF7EC,
    dark: 0xFFEFAE6E,
    nose: _pinkNose,
    tail: _Tail.striped,
    whiskers: true,
  ),
  'gato_negro': _Animal(fur: 0xFF3A3346, dark: 0xFF3A3346, nose: _pinkNose, tail: _Tail.plain, whiskers: true),
  'zarigueya': _Animal(
    fur: 0xFFF7F4F0,
    body: 0xFFA9A6AE,
    ear: _Ear.round,
    earColor: 0xFF3A3346,
    innerEar: 0xFFF7B3C2,
    nose: _pinkNose,
    feet: 0xFFF7B3C2,
    tail: _Tail.thin,
  ),
  'pato': _Animal(fur: _white, belly: 0xFFF3F1F6, ear: _Ear.none, feet: _orange, tail: _Tail.duck),
  'shiba': _Animal(fur: 0xFFF2A33A, belly: 0xFFFFF4E6, dark: 0xFFFFF4E6, innerEar: 0xFFFFF4E6, tail: _Tail.curl),
  'capibara': _Animal(fur: 0xFFB98A5E, dark: 0xFF9C7350, ear: _Ear.small, earColor: 0xFF9C7350, tail: _Tail.none),
  'panda': _Animal(
    fur: 0xFFF8F8F8,
    body: 0xFF3A3346,
    belly: 0xFFF8F8F8,
    dark: 0xFF3A3346,
    ear: _Ear.round,
    earColor: 0xFF3A3346,
    innerEar: 0xFF3A3346,
    feet: 0xFF3A3346,
    tail: _Tail.stub,
  ),
};

class _Costume {
  const _Costume(this.hood, {this.belly, this.feet});
  final int hood;
  final int? belly;
  final int? feet;
}

const _costumes = <String, _Costume>{
  'disfraz_tiburon': _Costume(0xFF8DB8D8, belly: 0xFFF4F8FC),
  'disfraz_fresa': _Costume(0xFFE8453C),
  'disfraz_rana': _Costume(0xFF7CC46A, belly: 0xFFD4EFB8),
  'disfraz_patito': _Costume(0xFFFFD54A, belly: 0xFFFFEBA3, feet: _orange),
  'disfraz_osito': _Costume(0xFFA47148, belly: 0xFFE7C39E),
  'disfraz_dino': _Costume(0xFF79C27A, belly: 0xFFCFEFB9),
};

class PixelSprite {
  static const n = 32;
  static final _cache = <String, List<int>>{};

  /// Colores ARGB de cada píxel (0 = transparente), fila por fila.
  /// [stage] es cuánto se ha comido del tomate (0 entero … [tomatoStages] nada).
  static List<int> build(AvatarLook look, AvatarMood mood, {SpriteProp prop = SpriteProp.ninguno, int stage = 0}) =>
      _cache.putIfAbsent('$look|${mood.name}|${prop.name}|$stage', () => _Builder(look, mood, prop, stage).run());

  static const tomatoStages = 8;

  /// Ancho de la escena del mapache acostado.
  static const bedWidth = 48;

  /// El personaje acostado y dormido, arropado con la cobija (48 × 32).
  /// [frame] mueve las "Z".
  static List<int> sleeping(AvatarLook look, int frame) =>
      _cache.putIfAbsent('$look|cama|${frame % 2}', () => _bed(build(look, AvatarMood.dormido), frame % 2));

  static List<int> _bed(List<int> sprite, int frame) {
    const w = bedWidth;
    final px = List<int>.filled(w * n, 0);
    void set(int x, int y, int c) {
      if (x >= 0 && y >= 0 && x < w && y < n) px[y * w + x] = c;
    }

    // Rellena la figura con borde de tinta (como _Builder._shape).
    void shape(bool Function(int x, int y) m, int color, {bool outline = true}) {
      for (var y = 0; y < n; y++) {
        for (var x = 0; x < w; x++) {
          if (!m(x, y)) continue;
          final edge = !m(x - 1, y) || !m(x + 1, y) || !m(x, y - 1) || !m(x, y + 1);
          set(x, y, outline && edge ? _ink : color);
        }
      }
    }

    bool Function(int, int) ellipse(double cx, double cy, double rx, double ry) => (x, y) {
      final dx = (x + .5 - cx) / rx, dy = (y + .5 - cy) / ry;
      return dx * dx + dy * dy <= 1;
    };

    // Almohada
    shape(ellipse(11, 26.5, 10.5, 4.2), 0xFFF4F1FA);
    shape((x, y) => y == 26 && x >= 3 && x <= 18 && x.isEven, 0xFFDCD6EA, outline: false);
    // Cabeza (filas de arriba del sprite), recostada en la almohada
    const dx = -3, dy = 4;
    for (var y = 0; y <= 21; y++) {
      for (var x = 0; x < n; x++) {
        final c = sprite[y * n + x];
        if (c != 0) set(x + dx, y + dy, c);
      }
    }
    // Colita de anillos que sale al final de la cobija
    final tail = ellipse(44.5, 28, 3.4, 2.2);
    shape(tail, 0xFFA09DAB);
    shape((x, y) => tail(x, y) && (x == 43 || x == 46) && y > 26 && y < 30, 0xFF67627A, outline: false);
    // Cobija con estrellitas: el bulto es el cuerpo
    final hump = ellipse(31, 25.5, 14, 7.5);
    bool blanket(int x, int y) => (hump(x, y) || (x >= 17 && x <= 44 && y >= 25)) && y <= 31;
    shape(blanket, 0xFF8E7CF0);
    shape((x, y) => blanket(x, y) && y == 26 && x > 18 && x < 44, 0xFFB9AEFF, outline: false);
    for (final (x, y) in const [(22, 29), (27, 22), (33, 27), (38, 21), (41, 29), (30, 30)]) {
      set(x, y, 0xFFFFE08A);
    }
    // Z z
    const big = [
      (0, 0),
      (1, 0),
      (2, 0),
      (3, 0),
      (4, 0),
      (3, 1),
      (2, 2),
      (1, 3),
      (0, 4),
      (1, 4),
      (2, 4),
      (3, 4),
      (4, 4),
    ];
    const small = [(0, 0), (1, 0), (2, 0), (3, 0), (2, 1), (1, 2), (0, 3), (1, 3), (2, 3), (3, 3)];
    final (bx, by, sx, sy) = frame == 0 ? (27, 5, 34, 11) : (29, 2, 35, 9);
    for (final (x, y) in big) {
      set(bx + x, by + y, 0xFF6C5CE7);
    }
    for (final (x, y) in small) {
      set(sx + x, sy + y, 0xFF8E7CF0);
    }
    return px;
  }
}

class _Builder {
  _Builder(this.look, this.requestedMood, this.prop, this.stage);

  final AvatarLook look;
  final AvatarMood requestedMood;
  final SpriteProp prop;
  final int stage;
  final _px = List<int>.filled(PixelSprite.n * PixelSprite.n, 0);

  static const n = PixelSprite.n;

  int _get(int x, int y) => x < 0 || y < 0 || x >= n || y >= n ? 0 : _px[y * n + x];
  void _set(int x, int y, int c) {
    if (x >= 0 && y >= 0 && x < n && y < n) _px[y * n + x] = c;
  }

  /// Rellena la figura; con [outline] su borde interior queda en tinta.
  void _shape(_Mask m, int color, {bool outline = true}) {
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (!m(x, y)) continue;
        final edge = !m(x - 1, y) || !m(x + 1, y) || !m(x, y - 1) || !m(x, y + 1);
        _set(x, y, outline && edge ? _ink : color);
      }
    }
  }

  /// Pinta solo dentro de [clip] (sin borde).
  void _paintIn(_Mask m, _Mask clip, int color) => _shape(_and(m, clip), color, outline: false);

  void _dots(List<(int, int)> pts, int color, {bool mirror = false}) {
    for (final (x, y) in pts) {
      _set(x, y, color);
      if (mirror) _set(n - 1 - x, y, color);
    }
  }

  /// Tinta o claro según si el píxel de abajo es oscuro (para panda y gato negro).
  int _feature(int x, int y) {
    final c = _get(x, y);
    if (c == 0) return _ink;
    final r = (c >> 16) & 0xFF, g = (c >> 8) & 0xFF, b = c & 0xFF;
    return (r * 299 + g * 587 + b * 114) / 1000 < 90 ? 0xFFF4F1F8 : _ink;
  }

  void _featureDots(List<(int, int)> pts, {bool mirror = true}) {
    for (final (x, y) in pts) {
      _set(x, y, _feature(x, y));
      if (mirror) _set(n - 1 - x, y, _feature(n - 1 - x, y));
    }
  }

  // ---------- Máscaras ----------
  static _Mask _ellipse(double cx, double cy, double rx, double ry) => (x, y) {
    final dx = (x + .5 - cx) / rx, dy = (y + .5 - cy) / ry;
    return dx * dx + dy * dy <= 1;
  };

  static _Mask _rect(int x0, int y0, int x1, int y1) =>
      (x, y) => x >= x0 && x <= x1 && y >= y0 && y <= y1;

  static _Mask _tri(double ax, double ay, double bx, double by, double cx, double cy) => (x, y) {
    final px = x + .5, py = y + .5;
    double s(double x1, double y1, double x2, double y2) => (px - x2) * (y1 - y2) - (x1 - x2) * (py - y2);
    final d1 = s(ax, ay, bx, by), d2 = s(bx, by, cx, cy), d3 = s(cx, cy, ax, ay);
    final neg = d1 < 0 || d2 < 0 || d3 < 0, pos = d1 > 0 || d2 > 0 || d3 > 0;
    return !(neg && pos);
  };

  static _Mask _or(_Mask a, _Mask b) =>
      (x, y) => a(x, y) || b(x, y);
  static _Mask _and(_Mask a, _Mask b) =>
      (x, y) => a(x, y) && b(x, y);
  static _Mask _not(_Mask a) =>
      (x, y) => !a(x, y);
  static _Mask _both(_Mask a) =>
      (x, y) => a(x, y) || a(n - 1 - x, y);
  static _Mask _rows(int from, int to) =>
      (x, y) => y >= from && y <= to;

  static final _head = _ellipse(16, 14, 10.5, 8);
  static final _hoodOuter = _and(_ellipse(16, 13, 12.2, 10.2), _rows(0, 21));
  static final _hoodWindow = _ellipse(16, 15, 8.6, 5.9);
  static final _hood = _and(_hoodOuter, _not(_hoodWindow));

  // ---------- Armado ----------
  List<int> run() {
    final sp = _animals[look.animal] ?? _animals['mapache']!;
    final costume = _costumes[look.cabeza];
    final mood = requestedMood != AvatarMood.normal
        ? requestedMood
        : switch (look.efecto) {
            'en_llamas' => AvatarMood.grito,
            'bateria_baja' => AvatarMood.dormido,
            _ => AvatarMood.normal,
          };

    _effectBehind();
    _tail(sp, costume);
    _body(sp, costume);
    if (costume == null) _ears(sp);
    _shape(_head, sp.fur);
    _markings(sp);
    _eyes(sp, mood);
    _blushAndMouth(sp, mood);
    if (sp.whiskers && costume == null) {
      final color = look.animal == 'gato_negro' ? 0xFF8A8296 : _ink;
      _dots([(3, 15), (4, 15), (5, 15), (3, 18), (4, 17), (5, 17)], color, mirror: true);
    }
    if (costume != null) _hoodCostume(costume);
    _hat();
    _faceItem();
    _effectFront();
    switch (prop) {
      case SpriteProp.tomate:
        _tomato(sp, costume);
      case SpriteProp.libro:
        _book(sp, costume);
      case SpriteProp.ninguno:
        break;
    }
    return _px;
  }

  /// Patitas que sostienen el objeto.
  void _paws(_Animal sp, _Costume? costume, double y) {
    _shape(_both(_ellipse(9.8, y, 2.1, 1.9)), costume?.hood ?? sp.feet ?? sp.body ?? sp.fur);
  }

  /// Tomate que se va comiendo a mordiscos: [stage] de 0 (entero) a 8 (nada).
  void _tomato(_Animal sp, _Costume? costume) {
    void calyx(int y) {
      _dots([(15, y), (16, y)], 0xFF2E7D32);
      _dots([for (var x = 13; x <= 18; x++) (x, y + 1)], 0xFF4CAF50);
      _dots([(14, y + 2), (17, y + 2)], 0xFF4CAF50);
    }

    if (stage >= PixelSprite.tomatoStages) {
      calyx(23); // solo queda el cabito
      _paws(sp, costume, 25);
      return;
    }
    const bites = [(20.5, 18.5), (11.5, 18.5), (16.0, 18.0), (22.0, 23.0), (10.0, 23.0), (16.0, 22.0), (19.5, 27.5)];
    _Mask eaten = (_, _) => false;
    for (var i = 0; i < stage && i < bites.length; i++) {
      eaten = _or(eaten, _ellipse(bites[i].$1, bites[i].$2, 3.2, 3.2));
    }
    final tomato = _and(_ellipse(16, 23.5, 6.2, 5.2), _not(eaten));
    _shape(tomato, 0xFFE8453C);
    // Pulpa donde ya mordió, con semillitas
    final inner = _and(tomato, _not(_edgeOf(tomato)));
    bool near(int x, int y) {
      for (var dy = -2; dy <= 2; dy++) {
        for (var dx = -2; dx <= 2; dx++) {
          if (dx.abs() + dy.abs() <= 2 && eaten(x + dx, y + dy)) return true;
        }
      }
      return false;
    }

    final pulp = _and(inner, near);
    _paintIn(pulp, inner, 0xFFFFB59C);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (pulp(x, y) && (x * 3 + y) % 5 == 0) _set(x, y, 0xFFFFE27A);
      }
    }
    if (inner(12, 21) && !pulp(12, 21)) _dots([(12, 21), (12, 22)], 0xFFFF8F84);
    if (stage < 3) calyx(17);
    _paws(sp, costume, 25);
  }

  /// Libro abierto para estudiar.
  void _book(_Animal sp, _Costume? costume) {
    _shape(_rect(7, 21, 24, 28), 0xFF6C5CE7);
    _shape(_or(_rect(8, 21, 15, 27), _rect(16, 21, 23, 27)), 0xFFFFFCF2, outline: false);
    _dots([for (var y = 21; y <= 27; y++) (15, y)], 0xFFDCD3BC);
    _dots([for (var y = 21; y <= 27; y++) (16, y)], 0xFFE9E1CB);
    for (final y in const [23, 25, 26]) {
      _dots([for (var x = 9; x <= 13; x++) (x, y)], 0xFF9F98B5);
      _dots([for (var x = 18; x <= 22; x++) (x, y)], 0xFF9F98B5);
    }
    _dots([(9, 22), (10, 22), (11, 22)], 0xFF6C5CE7); // título
    _paws(sp, costume, 26.5);
  }

  void _tail(_Animal sp, _Costume? costume) {
    if (costume != null) {
      switch (look.cabeza) {
        case 'disfraz_tiburon':
          _shape(_tri(21, 27, 29.5, 19, 27.5, 30), costume.hood);
        case 'disfraz_dino':
          _shape(_tri(21, 23, 30.5, 29, 21, 31), costume.hood);
          _shape(_tri(25, 25.5, 26.5, 22, 28, 27), 0xFFFF9F43);
        case 'disfraz_fresa':
          _shape(_ellipse(25.5, 25.5, 2.2, 4.5), costume.hood);
        default:
          _shape(_ellipse(24.5, 27.5, 2.4, 2.4), costume.hood);
      }
      return;
    }
    switch (sp.tail) {
      case _Tail.rings:
        final m = _ellipse(26, 24.5, 3, 5.2);
        _shape(m, sp.fur);
        _paintIn(_or(_rows(21, 21), _or(_rows(24, 24), _rows(27, 28))), _and(m, _not(_edgeOf(m))), sp.dark);
      case _Tail.striped:
        final m = _or(_ellipse(25, 28.5, 3.6, 1.8), _ellipse(27.5, 25.5, 1.6, 3.2));
        _shape(m, sp.fur);
        _paintIn((x, y) => x == 25 || x == 27 && y == 25, _and(m, _not(_edgeOf(m))), sp.dark);
      case _Tail.plain:
        _shape(_or(_ellipse(25, 28.5, 3.6, 1.8), _ellipse(27.5, 25.5, 1.6, 3.2)), sp.body ?? sp.fur);
      case _Tail.curl:
        _shape(_ellipse(24.5, 22.5, 3.2, 3.2), sp.fur);
        _dots([(24, 22), (25, 22), (24, 23)], sp.belly ?? _white);
      case _Tail.thin:
        _shape(_or(_ellipse(25, 29, 4.6, 1.5), _ellipse(28.5, 26.5, 1.5, 2.6)), 0xFFF6B3C1);
      case _Tail.stub:
        _shape(_ellipse(23.5, 28.5, 2, 2), sp.body ?? sp.fur);
      case _Tail.duck:
        _shape(_tri(21, 23, 26.5, 21.5, 22.5, 27.5), sp.fur);
      case _Tail.none:
        break;
    }
  }

  _Mask _edgeOf(_Mask m) =>
      (x, y) => m(x, y) && (!m(x - 1, y) || !m(x + 1, y) || !m(x, y - 1) || !m(x, y + 1));

  void _body(_Animal sp, _Costume? costume) {
    final body = _ellipse(16, 25.5, 7.5, 5.5);
    final color = costume?.hood ?? sp.body ?? sp.fur;
    _shape(body, color);
    final belly = costume != null ? costume.belly : sp.belly;
    if (belly != null) _paintIn(_ellipse(16, 26.8, 4.2, 3.4), _and(body, _not(_edgeOf(body))), belly);
    if (look.cabeza == 'disfraz_fresa') _seeds(_and(body, _not(_edgeOf(body))));
    final feet = costume?.feet ?? sp.feet ?? (belly ?? color);
    _shape(_both(_ellipse(12.5, 30.2, 2.5, 1.7)), feet);
  }

  void _ears(_Animal sp) {
    final outer = sp.earColor ?? sp.fur;
    switch (sp.ear) {
      case _Ear.pointy:
        _shape(_both(_tri(6.2, 12, 8, 1.8, 14.2, 7.2)), outer);
        _shape(_both(_tri(8.2, 9.4, 8.8, 5, 11.8, 7.6)), sp.innerEar, outline: false);
      case _Ear.round:
        _shape(_both(_ellipse(8.5, 7.5, 3.6, 3.6)), outer);
        _shape(_both(_ellipse(8.5, 7.8, 1.6, 1.6)), sp.innerEar, outline: false);
      case _Ear.small:
        _shape(_both(_ellipse(9, 8.2, 2.5, 2.3)), outer);
      case _Ear.none:
        _shape(_tri(14.5, 7, 17, 3, 17.5, 7), sp.fur); // copete
    }
  }

  void _markings(_Animal sp) {
    final inside = _and(_head, _not(_edgeOf(_head)));
    switch (look.animal) {
      case 'mapache':
        _paintIn(_ellipse(16, 17.4, 3.8, 2.5), inside, sp.belly!);
        _paintIn(_both(_ellipse(12, 14, 3.9, 2.5)), inside, sp.dark);
        _paintIn(_rect(15, 6, 16, 9), inside, sp.dark);
      case 'gato':
        _dots([(12, 7), (12, 8), (15, 6), (15, 7), (16, 6), (16, 7), (19, 7), (19, 8)], sp.dark);
        _dots([(6, 13), (7, 13), (6, 15)], sp.dark, mirror: true);
      case 'shiba':
        _paintIn(_ellipse(16, 18.6, 7.6, 3.9), inside, sp.belly!);
        _dots([(11, 11), (12, 11)], sp.belly!, mirror: true);
      case 'capibara':
        _paintIn(_ellipse(16, 16.8, 4.8, 2.7), inside, sp.dark);
      case 'panda':
        _paintIn(_both(_ellipse(12, 14.3, 2.9, 3.3)), inside, sp.dark);
    }
  }

  void _eyes(_Animal sp, AvatarMood mood) {
    switch (mood) {
      case AvatarMood.normal || AvatarMood.concentrado:
        if (look.animal == 'gato_negro') {
          for (final ex in [10, 19]) {
            for (var dy = 0; dy < 3; dy++) {
              for (var dx = 0; dx < 3; dx++) {
                _set(ex + dx, 12 + dy, 0xFFF5B83D);
              }
            }
            _set(ex + 1, 13, _ink);
            _set(ex + 1, 14, _ink);
            _set(ex, 12, _white);
          }
        } else {
          for (final ex in [11, 19]) {
            final light = _feature(ex, 13) != _ink;
            for (final (dx, dy) in const [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2), (1, 2)]) {
              _set(ex + dx, 12 + dy, light ? _white : _ink);
            }
            if (light) {
              _set(ex + 1, 13, _ink);
              _set(ex + 1, 14, _ink);
            } else {
              _set(ex, 12, _white);
            }
          }
        }
        if (mood == AvatarMood.concentrado) _featureDots([(10, 10), (11, 11), (12, 11)]);
      case AvatarMood.feliz || AvatarMood.comiendo:
        _featureDots([(10, 14), (11, 13), (12, 13), (13, 14)]);
      case AvatarMood.dormido:
        _featureDots([(10, 14), (11, 14), (12, 14), (13, 14)]);
      case AvatarMood.grito:
        _featureDots([(10, 12), (11, 13), (12, 13), (10, 14)]);
    }
  }

  void _blushAndMouth(_Animal sp, AvatarMood mood) {
    if (look.animal != 'gato_negro') _dots([(8, 16), (9, 16)], _blush, mirror: true);
    if (look.animal == 'pato') {
      _shape(_ellipse(16, 17.2, 3.4, 1.8), _orange);
      if (mood == AvatarMood.grito) _dots([(14, 17), (15, 17), (16, 17), (17, 17)], 0xFFC93752);
      return;
    }
    if (look.animal == 'capibara') {
      _dots([(14, 16), (17, 16)], _ink);
      if (mood == AvatarMood.grito) _dots([(15, 18), (16, 18)], 0xFFC93752);
      return;
    }
    if (mood == AvatarMood.grito) {
      _shape(_rect(14, 16, 17, 20), 0xFFC93752);
      _dots([(15, 19), (16, 19)], 0xFFFF9EB1);
      return;
    }
    final nose = look.animal == 'zarigueya' ? [(15, 16), (16, 16), (15, 17), (16, 17)] : [(15, 16), (16, 16)];
    if (sp.nose == _ink) {
      _featureDots(nose, mirror: false);
    } else {
      _dots(nose, sp.nose);
    }
    final y = look.animal == 'zarigueya' ? 1 : 0;
    switch (mood) {
      case AvatarMood.comiendo: // boca abierta masticando
        _dots([(15, 17 + y), (16, 17 + y)], _ink);
        _dots([(15, 18 + y), (16, 18 + y)], 0xFFC93752);
        _featureDots([(14, 17 + y)], mirror: true);
      case AvatarMood.feliz:
        _featureDots([(14, 17 + y), (15, 18 + y)], mirror: true);
        _dots([(15, 17 + y), (16, 17 + y)], 0xFFFF7A93);
      case AvatarMood.dormido:
        _featureDots([(15, 18 + y)], mirror: true);
      case AvatarMood.concentrado:
        _featureDots([(14, 18 + y), (15, 18 + y)], mirror: true);
      default:
        _featureDots([(14, 17 + y), (15, 18 + y)], mirror: true);
    }
  }

  void _seeds(_Mask area) {
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (area(x, y) && (x * 7 + y * 3) % 9 == 0) _set(x, y, 0xFFFFE27A);
      }
    }
  }

  void _hoodCostume(_Costume c) {
    final inner = _and(_hood, _not(_edgeOf(_hood)));
    switch (look.cabeza) {
      case 'disfraz_tiburon':
        _shape(_tri(14, 4.5, 18.5, -1, 21, 5.5), 0xFF6E9DC4);
        _shape(_hood, c.hood);
        _paintIn(_rows(0, 7), inner, 0xFF6E9DC4);
        for (var x = 9; x <= 22; x++) {
          var top = -1;
          for (var y = 8; y < 16; y++) {
            if (_hoodWindow(x, y)) {
              top = y;
              break;
            }
          }
          if (top < 0) continue;
          _set(x, top, _white);
          if (x.isOdd) _set(x, top + 1, _white);
        }
      case 'disfraz_fresa':
        _shape(_hood, c.hood);
        _seeds(inner);
        _shape(_or(_tri(9.5, 4.5, 12.5, 0.5, 16, 4), _tri(16, 4, 19.5, 0.5, 22.5, 4.5)), 0xFF4CAF50);
        _shape(_tri(13, 3.5, 16, -1.5, 19, 3.5), 0xFF3E9B45);
      case 'disfraz_rana':
        _shape(_hood, c.hood);
        _shape(_both(_ellipse(10, 4.5, 3.3, 3.3)), c.hood);
        _shape(_both(_ellipse(10, 4.5, 2, 2)), _white, outline: false);
        _dots([(9, 4), (10, 4), (9, 5), (10, 5)], _ink, mirror: true);
      case 'disfraz_patito':
        _shape(_hood, c.hood);
        _shape(_ellipse(16, 6.8, 3.7, 1.7), _orange);
        _dots([(11, 4), (11, 5)], _ink, mirror: true);
      case 'disfraz_osito':
        _shape(_both(_ellipse(7.5, 5, 3.4, 3.4)), c.hood);
        _shape(_hood, c.hood);
        _shape(_both(_ellipse(7.5, 5, 1.6, 1.6)), c.belly!, outline: false);
      case 'disfraz_dino':
        _shape(
          _or(
            _tri(8.5, 7, 10.5, 1.5, 13.5, 5.5),
            _or(_tri(13.5, 4.5, 16, -1, 18.5, 4.5), _tri(18.5, 5.5, 21.5, 1.5, 23.5, 7)),
          ),
          0xFFFF9F43,
        );
        _shape(_hood, c.hood);
        _paintIn(_both(_ellipse(9, 12, 1, 1)), inner, 0xFF5FA860);
    }
  }

  void _hat() {
    switch (look.cabeza) {
      case 'mono':
        _shape(_or(_tri(22, 6, 18.5, 3, 18.5, 9), _tri(22, 6, 25.5, 3, 25.5, 9)), 0xFFFF7FA8);
        _dots([(21, 5), (22, 5), (21, 6), (22, 6)], 0xFFE0558A);
      case 'flor':
        _shape(
          _or(
            _or(_ellipse(9.5, 3.9, 1.8, 1.8), _ellipse(11.6, 6, 1.8, 1.8)),
            _or(_ellipse(9.5, 8.1, 1.8, 1.8), _ellipse(7.4, 6, 1.8, 1.8)),
          ),
          0xFFFFB3CF,
        );
        _dots([(9, 5), (10, 5), (9, 6), (10, 6)], 0xFFFFD34D);
      case 'gorro_lana':
        _shape(_and(_ellipse(16, 8.5, 9.8, 6.5), _rows(0, 8)), 0xFFFF9F43);
        _shape(_rect(6, 7, 25, 9), 0xFFE07F22);
        for (var x = 8; x <= 23; x += 2) {
          _set(x, 8, 0xFFC96A1A);
        }
        _shape(_ellipse(16, 2.2, 2.3, 2.1), 0xFFFFF1E2);
      case 'birrete':
        _shape(_rect(10, 4, 21, 7), 0xFF3A3346);
        _shape((x, y) => (x + .5 - 16).abs() / 10.8 + (y + .5 - 2.6).abs() / 2.4 <= 1, 0xFF4A4160);
        _dots([(16, 2), (17, 2)], 0xFFFFC23D);
        _dots([(24, 3), (24, 4), (24, 5), (24, 6), (23, 7), (24, 7), (25, 7)], 0xFFFFC23D);
      case 'corona':
        _shape(
          _or(
            _rect(10, 3, 21, 6),
            _or(
              _tri(9.5, 4, 11.5, -0.5, 13.5, 4),
              _or(_tri(13.5, 4, 16, -1.5, 18.5, 4), _tri(18.5, 4, 20.5, -0.5, 22.5, 4)),
            ),
          ),
          0xFFFFC93C,
        );
        _dots([(15, 4), (16, 4)], 0xFFE5484D);
        _dots([(12, 5)], 0xFF5D9AFE);
        _dots([(19, 5)], 0xFF22D39A);
    }
  }

  void _faceItem() {
    switch (look.cara) {
      case 'lentes':
        for (final cx in [12.0, 20.0]) {
          bool ring(int x, int y) {
            final dx = x + .5 - cx, dy = y + .5 - 14;
            final d = dx * dx + dy * dy;
            return d >= 4.4 && d <= 9.6;
          }

          _shape(ring, _ink, outline: false);
        }
        _dots([(15, 13), (16, 13)], _ink);
      case 'gafas_sol':
        _shape(_or(_rect(9, 12, 14, 15), _rect(17, 12, 22, 15)), 0xFF1E1A26, outline: false);
        _dots([(15, 12), (16, 12)], 0xFF1E1A26);
        _dots([(10, 13), (11, 13), (18, 13), (19, 13)], 0xFFB9B3C6);
      case 'curita':
        _shape(_rect(20, 15, 25, 17), 0xFFF5CFA0);
        _dots([(22, 16), (23, 16)], 0xFFE3B47C);
    }
  }

  void _effectBehind() {
    switch (look.efecto) {
      case 'en_llamas':
        const tongues = [
          (1.0, 5.0, 11.0, 12.0),
          (6.0, 10.0, 16.0, 4.0),
          (12.0, 16.0, 20.0, -1.0),
          (16.0, 22.0, 26.0, 4.0),
          (21.0, 27.0, 31.0, 12.0),
        ];
        for (final (color, shrink, lift) in const [
          (0xFFFF5A36, 1.0, 0.0),
          (0xFFFF9F43, .7, 5.0),
          (0xFFFFD84D, .42, 10.0),
        ]) {
          _Mask m = (_, _) => false;
          for (final (l, tip, r, ty) in tongues) {
            final half = (r - l) / 2 * shrink;
            m = _or(m, _tri(tip - half, 32, tip, ty + lift, tip + half, 32));
          }
          _shape(m, color, outline: false);
        }
      case 'corazones':
        _heart(1, 3);
        _heart(26, 2);
        _heart(27, 19);
    }
  }

  void _heart(int ox, int oy) {
    const rows = ['01010', '11111', '01110', '00100'];
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < 5; x++) {
        if (rows[y][x] == '1') _set(ox + x, oy + y, 0xFFFF6B9A);
      }
    }
  }

  void _effectFront() {
    switch (look.efecto) {
      case 'brillitos':
        for (final (x, y) in const [(3, 5), (28, 4), (28, 19), (3, 21)]) {
          _dots([(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], 0xFFFFD34D);
        }
      case 'bateria_llena':
        _shape(_rect(10, 0, 19, 4), _white);
        _dots([(20, 1), (20, 2), (20, 3)], _ink);
        for (var x = 11; x <= 18; x++) {
          _dots([(x, 1), (x, 2), (x, 3)], 0xFF10AC84);
        }
        _dots([(13, 2), (16, 2)], 0xFF0B8A69);
      case 'bateria_baja':
        _shape(_rect(10, 0, 19, 4), _white);
        _dots([(20, 1), (20, 2), (20, 3)], _ink);
        _dots([(11, 1), (12, 1), (11, 2), (12, 2), (11, 3), (12, 3)], 0xFFE5484D);
        _dots([(26, 7), (27, 7), (28, 7), (27, 8), (26, 9), (27, 9), (28, 9)], _ink);
    }
  }
}
