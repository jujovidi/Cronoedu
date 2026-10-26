/// Partes del avatar que se pueden cambiar.
enum AvatarSlot {
  animal('Animales'),
  cabeza('Disfraces y gorros'),
  cara('Cara'),
  efecto('Efectos'),
  fondo('Fondos');

  const AvatarSlot(this.label);
  final String label;

  /// Los accesorios se pueden quitar; el animal y el fondo no.
  bool get optional => this == cabeza || this == cara || this == efecto;
}

/// Un animal, disfraz, accesorio, efecto o fondo de la tienda. Se compra con
/// bellotas y algunos piden un nivel mínimo.
class AvatarItem {
  const AvatarItem(this.id, this.name, this.slot, {this.price = 0, this.level = 1, this.hint = ''});

  final String id;
  final String name;
  final AvatarSlot slot;
  final int price;
  final int level;

  /// Frase corta que se muestra al comprarlo.
  final String hint;

  bool get isFree => price == 0 && level <= 1;
}

class AvatarCatalog {
  static const items = <AvatarItem>[
    // Animales
    AvatarItem('mapache', 'Mapache', AvatarSlot.animal, hint: 'La mascota de CronoEdu.'),
    AvatarItem('gato', 'Gatito', AvatarSlot.animal, price: 60, level: 2, hint: 'Atigrado y siempre con sueño.'),
    AvatarItem('zarigueya', 'Zarigüeya', AvatarSlot.animal, price: 60, level: 2, hint: 'Grita cuando ve un parcial.'),
    AvatarItem('pato', 'Patito', AvatarSlot.animal, price: 80, level: 2, hint: 'Cuac.'),
    AvatarItem('shiba', 'Shiba', AvatarSlot.animal, price: 100, level: 3, hint: 'Batería baja, pero leal.'),
    AvatarItem('capibara', 'Capibara', AvatarSlot.animal, price: 120, level: 3, hint: 'Nada lo estresa.'),
    AvatarItem('gato_negro', 'Gato negro', AvatarSlot.animal, price: 150, level: 4, hint: 'Te juzga en silencio.'),
    AvatarItem('panda', 'Panda', AvatarSlot.animal, price: 200, level: 5, hint: 'Experto en siestas.'),
    // Disfraces y gorros
    AvatarItem('mono', 'Moñito', AvatarSlot.cabeza, price: 30),
    AvatarItem('flor', 'Flor', AvatarSlot.cabeza, price: 30),
    AvatarItem('gorro_lana', 'Gorro de lana', AvatarSlot.cabeza, price: 60, level: 2),
    AvatarItem('disfraz_fresa', 'Disfraz de fresa', AvatarSlot.cabeza, price: 120, level: 3),
    AvatarItem('disfraz_rana', 'Disfraz de rana', AvatarSlot.cabeza, price: 120, level: 3),
    AvatarItem('disfraz_patito', 'Disfraz de patito', AvatarSlot.cabeza, price: 140, level: 3),
    AvatarItem('disfraz_osito', 'Disfraz de osito', AvatarSlot.cabeza, price: 160, level: 4),
    AvatarItem('disfraz_tiburon', 'Disfraz de tiburón', AvatarSlot.cabeza, price: 200, level: 5),
    AvatarItem('disfraz_dino', 'Disfraz de dinosaurio', AvatarSlot.cabeza, price: 220, level: 5),
    AvatarItem('birrete', 'Birrete de grado', AvatarSlot.cabeza, price: 250, level: 6),
    AvatarItem('corona', 'Corona', AvatarSlot.cabeza, price: 400, level: 8),
    // Cara
    AvatarItem('curita', 'Curita', AvatarSlot.cara, price: 30),
    AvatarItem('lentes', 'Lentes redondos', AvatarSlot.cara, price: 40),
    AvatarItem('gafas_sol', 'Gafas de sol', AvatarSlot.cara, price: 90, level: 2),
    // Efectos
    AvatarItem('corazones', 'Corazones', AvatarSlot.efecto, price: 50, hint: 'Para los que aman estudiar.'),
    AvatarItem('brillitos', 'Brillitos', AvatarSlot.efecto, price: 80, level: 2),
    AvatarItem('bateria_baja', 'Batería baja', AvatarSlot.efecto, price: 100, level: 3, hint: 'Semana de parciales.'),
    AvatarItem(
      'en_llamas',
      'En llamas',
      AvatarSlot.efecto,
      price: 250,
      level: 6,
      hint: 'Cuando todo se entrega mañana.',
    ),
    // Fondos
    AvatarItem('lavanda', 'Lavanda', AvatarSlot.fondo),
    AvatarItem('cuadricula', 'Papel cuadriculado', AvatarSlot.fondo, price: 20),
    AvatarItem('rosa', 'Rosa', AvatarSlot.fondo, price: 30),
    AvatarItem('menta', 'Menta', AvatarSlot.fondo, price: 30),
    AvatarItem('cielo', 'Cielo', AvatarSlot.fondo, price: 30),
    AvatarItem('noche', 'Noche estrellada', AvatarSlot.fondo, price: 120, level: 4),
  ];

  static AvatarItem? byId(String? id) => id == null ? null : items.where((i) => i.id == id).firstOrNull;

  static List<AvatarItem> ofSlot(AvatarSlot slot) => items.where((i) => i.slot == slot).toList();

  /// Lo que se tiene sin comprar nada.
  static Set<String> get freeIds => items.where((i) => i.isFree).map((i) => i.id).toSet();

  /// [id] si existe y es de [slot]; si no, null (para datos guardados viejos).
  static String? valid(String? id, AvatarSlot slot) => byId(id)?.slot == slot ? id : null;
}

/// Cómo se ve el avatar: un animal, un fondo y hasta tres extras.
class AvatarLook {
  const AvatarLook({this.animal = 'mapache', this.fondo = 'lavanda', this.cabeza, this.cara, this.efecto});

  final String animal;
  final String fondo;
  final String? cabeza;
  final String? cara;
  final String? efecto;

  String? operator [](AvatarSlot slot) => switch (slot) {
    AvatarSlot.animal => animal,
    AvatarSlot.fondo => fondo,
    AvatarSlot.cabeza => cabeza,
    AvatarSlot.cara => cara,
    AvatarSlot.efecto => efecto,
  };

  /// Copia con [slot] cambiado ([id] null quita el extra).
  AvatarLook withItem(AvatarSlot slot, String? id) => AvatarLook(
    animal: slot == AvatarSlot.animal ? id ?? animal : animal,
    fondo: slot == AvatarSlot.fondo ? id ?? fondo : fondo,
    cabeza: slot == AvatarSlot.cabeza ? id : cabeza,
    cara: slot == AvatarSlot.cara ? id : cara,
    efecto: slot == AvatarSlot.efecto ? id : efecto,
  );

  Map<String, dynamic> toJson() => {
    'animal': animal,
    'fondo': fondo,
    if (cabeza != null) 'cabeza': cabeza,
    if (cara != null) 'cara': cara,
    if (efecto != null) 'efecto': efecto,
  };

  /// Lee un avatar guardado; lo que ya no exista en el catálogo se descarta.
  factory AvatarLook.fromJson(Map<String, dynamic>? json) => json == null
      ? const AvatarLook()
      : AvatarLook(
          animal: AvatarCatalog.valid(json['animal'] as String?, AvatarSlot.animal) ?? 'mapache',
          fondo: AvatarCatalog.valid(json['fondo'] as String?, AvatarSlot.fondo) ?? 'lavanda',
          cabeza: AvatarCatalog.valid(json['cabeza'] as String?, AvatarSlot.cabeza),
          cara: AvatarCatalog.valid(json['cara'] as String?, AvatarSlot.cara),
          efecto: AvatarCatalog.valid(json['efecto'] as String?, AvatarSlot.efecto),
        );

  @override
  bool operator ==(Object other) =>
      other is AvatarLook &&
      other.animal == animal &&
      other.fondo == fondo &&
      other.cabeza == cabeza &&
      other.cara == cara &&
      other.efecto == efecto;

  @override
  int get hashCode => Object.hash(animal, fondo, cabeza, cara, efecto);

  @override
  String toString() => toJson().values.join('|');
}
