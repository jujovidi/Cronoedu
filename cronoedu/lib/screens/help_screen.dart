import 'package:flutter/material.dart';

import '../widgets/mascot.dart';

/// Ayuda: tutorial, preguntas frecuentes y manual de usuario.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ayuda'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tutorial'),
              Tab(text: 'Preguntas'),
              Tab(text: 'Manual'),
            ],
          ),
        ),
        body: const TabBarView(children: [_TutorialTab(), _FaqTab(), _ManualTab()]),
      ),
    );
  }
}

// ---------------- Tutorial por módulos ----------------

class _Module {
  const _Module(this.icon, this.title, this.intro, this.steps, [this.pose = MascotPose.escritorio]);
  final IconData icon;
  final String title;

  /// Para qué sirve el módulo, en una o dos frases.
  final String intro;

  /// Pasos concretos para usarlo.
  final List<String> steps;
  final MascotPose pose;
}

const _modules = [
  _Module(
    Icons.home_rounded,
    'Módulo 1 · Inicio',
    'Tu resumen del día: cuántas tareas tienes pendientes, el calendario del mes y tu próximo espacio libre para estudiar.',
    [
      'Mira los puntos bajo cada día: rojo es una tarea pendiente y verde una completada.',
      'Desliza el calendario hacia arriba para verlo por semana y hacia abajo para volver al mes.',
      'Toca un día para ver sus entregas. Con "Agregar" creas una tarea para ese día (solo hoy o días futuros).',
      'La campanita te muestra el próximo espacio libre. Toca el calendario para agendarlo o "Procrastinar" para descartarlo.',
      'Toca el círculo de una tarea para marcarla como completada.',
    ],
  ),
  _Module(
    Icons.assignment_rounded,
    'Módulo 2 · Tareas',
    'Registra lo que debes entregar para que la app calcule cuánto te toma y cuándo empezar.',
    [
      'Escribe la materia y el tema (por ejemplo "Cálculo" y "Taller 3"). Ambos son obligatorios.',
      'Elige el día de entrega (obligatorio). La hora es opcional: úsala si la entrega tiene hora límite.',
      'Indica si la entregas virtual o en físico. Las de físico aparecen encima de tu clase de esa materia.',
      'Elige la complejidad: Tareita (~1,5 h), Proyecto (~6 h) o Proyecto final (~15 h).',
      'Edita o elimina una tarea con el menú de tres puntos que aparece a su derecha.',
    ],
  ),
  _Module(
    Icons.calendar_month_rounded,
    'Módulo 3 · Calendario y horario',
    'Tu semana completa: clases, ocio, trabajo, actividades extracurriculares, entregas y horas sugeridas para estudiar.',
    [
      'Cambia entre Mes y Semana con el selector de arriba.',
      'En Semana, las tareas se ven en translúcido sobre su hora de entrega (o sobre la clase si son en físico).',
      'Las horas sugeridas de estudio autónomo aparecen en verde translúcido: tócalas para agendarlas o descartarlas. Puedes ocultarlas con el interruptor.',
      'Con Ocio, Trabajo y Extracurricular marcas las horas en que no puedes estudiar. Si la hora de inicio y la de fin no son válidas, la app te avisa.',
      'En "Cargar horario" importas el PDF oficial de la universidad, editas tu horario o lo eliminas.',
    ],
  ),
  _Module(
    Icons.timer_rounded,
    'Módulo 4 · Técnicas de estudio',
    'Temporizadores que te ayudan a concentrarte y a descansar a tiempo.',
    [
      'Pomodoro: 25 min de enfoque y 5 de descanso; cada 4 ciclos el descanso es de 15 min. Como el Pomodoro nació con un reloj de cocina en forma de tomate, el mapache se come un tomate mientras estudias y lo termina justo a los 25 minutos.',
      'Flowtime: estudias a tu ritmo. Una sesión cuenta si dura al menos 10 minutos. El mapache estudia con su batería al 100 % y en el descanso se acuesta a dormir.',
      'En Flowtime, después de 2 horas te preguntamos cada hora "¿Sigues ahí?". Si no respondes en 1 minuto, empieza tu descanso.',
      'El descanso de Flowtime crece con lo que estudiaste; si pasas de 90 min, es ¼ del tiempo.',
      'Un ciclo se cierra cuando termina el descanso. Toca "?" para ver la explicación completa.',
    ],
    MascotPose.enfoque,
  ),
  _Module(
    Icons.lightbulb_rounded,
    'Módulo 5 · Sugerencias',
    'Tus tareas pendientes ordenadas por fecha, con un plan para cada una.',
    [
      'La tarjeta grande es la tarea más próxima a entregarse. Desliza para ver las siguientes.',
      'Cada tarjeta dice cuánto tiempo te tomará y tu próximo espacio libre.',
      'Abajo verás hasta 3 libros o atlas de las bibliotecas de la universidad, 2 videos de YouTube y 3 artículos sobre la materia y el tema. Tócalos para abrirlos.',
      'El check verde la marca como hecha y la pinta de verde en el calendario.',
      '"Empezar a estudiar" te lleva a Técnicas con esa tarea activa.',
    ],
    MascotPose.logro,
  ),
  _Module(
    Icons.notifications_active_rounded,
    'Módulo 6 · Notificaciones',
    'Aunque no abras la app, te avisamos para que aproveches tus espacios libres.',
    [
      '30 minutos antes de cada hora sugerida recibes una notificación.',
      '"Ver espacio" abre la app en ese espacio, "Agendar" lo guarda en tu horario y "Procrastinar" descarta la sugerencia.',
      'En sesiones largas de Flowtime también te llega el "¿Sigues ahí?".',
      'Puedes apagarlas en Perfil → Notificaciones.',
    ],
    MascotPose.descanso,
  ),
  _Module(
    Icons.emoji_events_rounded,
    'Módulo 7 · Recompensas',
    'Tu apartado de gamificación: estudia, gana bellotas, viste a tu avatar y compite en el ranking.',
    [
      'Ganas bellotas al cerrar un ciclo de Pomodoro o Flowtime (con al menos 10 min de enfoque), por cada 5 minutos de enfoque y al completar tareas (más si las entregas a tiempo).',
      'Estudia todos los días para mantener tu racha: el primer ciclo de cada día da un bono que crece con los días seguidos.',
      'Cada bellota ganada es un punto del ranking. Gastarlas en la tienda no te quita puntos ni te baja de nivel (subes uno cada 120 puntos).',
      'Entra a Recompensas desde el botón "Apartados". En "Mi avatar" elige animal (mapache, gatito, zarigüeya, patito, shiba, capibara, gato negro o panda), disfraces y gorros, algo para la cara, un efecto y el fondo.',
      'Toca algo que no tengas para verlo puesto y comprarlo. Los que tienen candado se abren al llegar a ese nivel. Toca un extra tuyo para ponértelo o quitártelo.',
      'En "Ranking" mira el podio de esta semana o de todo el tiempo y cuántos puntos te faltan para pasar al de arriba. Ahí apareces con tu nickname y tu avatar.',
    ],
    MascotPose.logro,
  ),
  _Module(Icons.person_rounded, 'Módulo 8 · Cuenta y perfil', 'Tu cuenta, tus datos y la configuración de la app.', [
    'Para usar CronoEdu creas una cuenta con nickname, correo y contraseña. El nickname es el nombre que se ve en el ranking.',
    'La próxima vez entras con tu correo o tu nickname y la contraseña.',
    'Toca tu avatar, arriba a la derecha, para abrir el perfil. Ahí editas tu nombre, carrera y semestre, y cambias entre modo claro, oscuro o el del sistema.',
    'En Ayuda tienes este tutorial, las preguntas frecuentes y el manual.',
    '"Cerrar sesión" guarda tus datos para cuando vuelvas; "Eliminar cuenta" los borra de este celular.',
  ], MascotPose.descanso),
];

class _TutorialTab extends StatelessWidget {
  const _TutorialTab();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      FilledButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorialScreen())),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('VER TUTORIAL PASO A PASO'),
      ),
      const SizedBox(height: 16),
      for (final m in _modules)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            shape: const Border(),
            leading: CircleAvatar(child: Icon(m.icon)),
            title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(m.intro, maxLines: 2, overflow: TextOverflow.ellipsis),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [_StepList(m.steps)],
          ),
        ),
    ],
  );
}

class _StepList extends StatelessWidget {
  const _StepList(this.steps);
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: scheme.primary,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(steps[i], style: const TextStyle(height: 1.35))),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tutorial a pantalla completa, un módulo por página (se muestra al entrar
/// por primera vez y desde Ayuda).
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final last = _page == _modules.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_page + 1} de ${_modules.length}', style: t.titleMedium),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Saltar'))],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _modules.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final m = _modules[i];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    Mascot(m.pose, size: 130),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(m.icon, color: scheme.primary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            m.title,
                            textAlign: TextAlign.center,
                            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(m.intro, textAlign: TextAlign.center, style: t.bodyLarge),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(padding: const EdgeInsets.all(16), child: _StepList(m.steps)),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _modules.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(3),
                  width: i == _page ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_page > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: OutlinedButton(
                      onPressed: () =>
                          _controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                      child: const Text('ATRÁS'),
                    ),
                  ),
                Expanded(
                  child: FilledButton(
                    onPressed: last
                        ? () => Navigator.pop(context)
                        : () =>
                              _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    child: Text(last ? '¡LISTO!' : 'SIGUIENTE'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Preguntas frecuentes ----------------

class _Faq {
  const _Faq(this.category, this.question, this.answer);
  final String category;
  final String question;
  final String answer;
}

const _faqs = [
  _Faq(
    'Tareas',
    '¿Cómo agrego una tarea?',
    'En Inicio toca un día del calendario y luego "Agregar" (o el botón "+ Tarea"). También desde Calendario → Tarea. Materia, tema y día de entrega son obligatorios; la hora y la descripción son opcionales.',
  ),
  _Faq(
    'Tareas',
    '¿Por qué no puedo elegir una fecha pasada?',
    'Las tareas nuevas solo pueden tener entrega hoy o en un día futuro, y si eliges hoy la hora no puede haber pasado.',
  ),
  _Faq(
    'Tareas',
    '¿Qué cambia si la entrega es en físico?',
    'En la vista Semana la tarea aparece encima de tu clase de esa materia ese día, para que recuerdes llevarla.',
  ),
  _Faq(
    'Tareas',
    '¿Qué significan los colores rojo y verde?',
    'Rojo: la tarea está pendiente. Verde: ya la completaste. Toca el círculo de la tarea para cambiar su estado.',
  ),
  _Faq(
    'Tareas',
    '¿Para qué sirve la complejidad?',
    'Tareita (~1,5 h), Proyecto (~6 h) y Proyecto final (~15 h). La app la usa para estimar cuánto tiempo necesitas, cuándo empezar y qué sugerirte primero.',
  ),
  _Faq(
    'Horario',
    '¿Cómo cargo mi horario de la universidad?',
    'En Academusoft descarga tu "Reporte de horario" en PDF. En la app ve a Calendario → Cargar horario → Cargar horario y elige el archivo. Revisa la lista y toca "Agregar".',
  ),
  _Faq(
    'Horario',
    'El PDF trae grupos que no son míos',
    'El reporte puede listar todas las líneas de una profundización. En la vista previa desmarca los grupos que no tomas antes de agregarlos. Luego también puedes borrar clases en Editar horario.',
  ),
  _Faq(
    'Horario',
    'Me sale "No encontré la tabla de horario"',
    'El archivo no es el reporte oficial o es una foto/escaneo. Descarga de nuevo el PDF desde Academusoft (no una captura de pantalla).',
  ),
  _Faq(
    'Horario',
    '¿Para qué agrego ocio, trabajo o extracurriculares?',
    'Para que la app sepa en qué horas NO puedes estudiar. Así detecta tus espacios libres y te recomienda tareas solo en esos momentos.',
  ),
  _Faq(
    'Estudio',
    '¿Qué técnica me conviene?',
    'Pomodoro si te cuesta arrancar o te distraes fácil (bloques fijos de 25 min). Flowtime si necesitas concentración larga, como en proyectos: tú decides cuándo parar.',
  ),
  _Faq(
    'Estudio',
    '¿Qué es un ciclo?',
    'Un enfoque válido más su descanso: el ciclo se cierra cuando el descanso termina o lo omites. Abandonar no suma ciclo.',
  ),
  _Faq(
    'Estudio',
    'Flowtime no me contó la sesión',
    'En Flowtime la sesión debe durar al menos 10 minutos para ser válida.',
  ),
  _Faq(
    'Estudio',
    '¿Qué es el "¿Sigues ahí?"?',
    'En Flowtime, desde las 2 horas de enfoque te preguntamos cada hora si sigues estudiando. Si no respondes en 1 minuto, cerramos el enfoque y empieza el descanso (¼ del tiempo estudiado si pasaste de 90 min).',
  ),
  _Faq(
    'Sugerencias',
    '¿Qué son las horas sugeridas en verde?',
    'Una hora libre por día que la app te propone para estudio autónomo, según tu horario y tus tareas pendientes. Si la agendas queda en tu horario; si no, desaparece.',
  ),
  _Faq(
    'Sugerencias',
    '¿De dónde sale el material para estudiar?',
    'De las bibliotecas digitales de la Universidad de Cundinamarca (ENI, Alpha Editorial Cloud, Eureka, BioAtlas y BioAtlasVet). El catálogo viene dentro de la app, así que la búsqueda funciona sin internet; para leer el libro sí necesitas internet y entrar con tu cuenta institucional. Si no aparece nada, escribe la materia o el tema con otras palabras.',
  ),
  _Faq(
    'Sugerencias',
    '¿Cómo se eligen los videos y artículos?',
    'Con la materia y el tema de tu tarea (sin palabras como "taller" o "parcial") armamos dos búsquedas en YouTube (explicación y ejercicios resueltos) y tres de artículos: Google Académico, SciELO y Wikipedia. Así siempre ves resultados actuales; elige los de fuentes confiables, como canales de universidades o revistas.',
  ),
  _Faq(
    'Sugerencias',
    '¿Qué hace "Procrastinar"?',
    'Descarta la sugerencia de ese día y no te volvemos a avisar por ella.',
  ),
  _Faq(
    'Sugerencias',
    'No me llegan las notificaciones',
    'Revisa que estén activas en Perfil → Notificaciones y que el celular le dé permiso a CronoEdu. Llegan 30 minutos antes de cada hora sugerida.',
  ),
  _Faq(
    'Avatar',
    '¿Cómo consigo bellotas?',
    'Cerrando ciclos de estudio (10 bellotas si el enfoque duró al menos 10 min), con 1 bellota por cada 5 min de enfoque, completando tareas (15, y 10 más si es a tiempo) y con el bono de racha del primer ciclo de cada día.',
  ),
  _Faq(
    'Avatar',
    '¿Por qué no me dieron bellotas por un ciclo?',
    'El ciclo solo paga si el enfoque duró al menos 10 minutos. Si lo cortas antes, solo cuentan los minutos estudiados.',
  ),
  _Faq(
    'Avatar',
    'Desmarqué una tarea y la volví a marcar, ¿por qué no sumó?',
    'Cada tarea da bellotas una sola vez, la primera vez que la completas.',
  ),
  _Faq(
    'Avatar',
    '¿Qué significa el candado en la tienda?',
    'Ese animal, disfraz o efecto se desbloquea al llegar al nivel que indica. Subes un nivel por cada 120 puntos; gastar no te baja de nivel.',
  ),
  _Faq(
    'Ranking',
    '¿Cómo se calculan los puntos del ranking?',
    'Son las bellotas que has ganado (estudiando, cerrando ciclos, cumpliendo tareas y con tu racha). Comprar en la tienda no te quita puntos. "Esta semana" cuenta desde el lunes.',
  ),
  _Faq(
    'Ranking',
    '¿Quiénes salen en el ranking?',
    'Por ahora, las cuentas creadas en este celular y algunos estudiantes de ejemplo para que puedas probarlo. Cuando conectemos la base de datos verás a los estudiantes de toda la universidad.',
  ),
  _Faq(
    'Cuenta',
    'Olvidé mi contraseña, ¿qué hago?',
    'Por ahora la cuenta vive solo en tu celular y no se puede recuperar. Cuando la app se conecte a la base de datos habrá recuperación por correo.',
  ),
  _Faq(
    'Cuenta',
    '¿Puedo cambiar mi nickname?',
    'Todavía no. Elige uno que te guste: es el nombre con el que apareces en el ranking.',
  ),
  _Faq(
    'Cuenta',
    '¿Mis datos se suben a internet?',
    'No. Todo se guarda solo en tu celular. Si eliminas la cuenta o desinstalas la app, se borran.',
  ),
  _Faq(
    'Cuenta',
    '¿Cómo activo el modo oscuro?',
    'Perfil → Apariencia → Oscuro. "Sistema" sigue la configuración de tu celular.',
  ),
];

class _FaqTab extends StatefulWidget {
  const _FaqTab();

  @override
  State<_FaqTab> createState() => _FaqTabState();
}

class _FaqTabState extends State<_FaqTab> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final categories = _faqs.map((f) => f.category).toSet().toList();
    final shown = _faqs.where((f) => _category == null || f.category == _category).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('¿Sobre qué necesitas ayuda?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todas'),
              selected: _category == null,
              onSelected: (_) => setState(() => _category = null),
            ),
            for (final c in categories)
              ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = c)),
          ],
        ),
        const SizedBox(height: 12),
        for (final f in shown)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              shape: const Border(),
              title: Text(f.question, style: const TextStyle(fontWeight: FontWeight.w700)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedAlignment: Alignment.centerLeft,
              children: [Text(f.answer)],
            ),
          ),
      ],
    );
  }
}

// ---------------- Manual ----------------

const _manual = [
  (
    '1. Primeros pasos',
    'Al abrir CronoEdu por primera vez crea tu cuenta con un nickname (el nombre que se verá en el ranking), tu correo y una contraseña de al menos 8 caracteres con letras y números. Luego escribe tu nombre, carrera y semestre y acepta el permiso de notificaciones. Las siguientes veces entras con tu correo o nickname. Por ahora todo queda guardado solo en tu celular (la contraseña se guarda cifrada con un hash, nunca tal cual).\n\n'
        'Usa el botón "Apartados" de abajo para moverte entre Inicio, Calendario, Técnicas, Sugerencias y Recompensas. Tu avatar, arriba a la derecha, abre tu perfil.',
  ),
  (
    '2. Inicio',
    'Muestra el mes actual. Cada punto bajo un día es una tarea (rojo pendiente, verde completada). Desliza el calendario hacia arriba para la vista semanal y hacia abajo para volver al mes. Al tocar un día ves sus entregas y puedes agregar tareas (solo hoy o días futuros).\n\n'
        'La campanita muestra únicamente tu próximo espacio libre para estudiar. El botón de calendario lo agenda en tu horario y "Procrastinar" descarta la sugerencia de ese día.',
  ),
  (
    '3. Tareas',
    'Campos: materia y tema (obligatorios), día de entrega (obligatorio, no puede ser pasado), hora de entrega (opcional), forma de entrega (virtual o en físico), complejidad y descripción opcional. La complejidad estima el tiempo: Tareita ~1,5 h, Proyecto ~6 h, Proyecto final ~15 h.',
  ),
  (
    '4. Calendario y horario',
    'Cambia entre Mes y Semana con el selector superior. La vista Semana es una cuadrícula de lunes a domingo con tus clases y actividades. Encima, en translúcido, verás:\n'
        '• Tus tareas en su hora de entrega; si son en físico, sobre la clase de esa materia ese día. Sin hora ni clase, aparecen como punto bajo la fecha.\n'
        '• Una hora sugerida de estudio autónomo por día (en verde). Tócala para agendarla o descartarla; si no la agendas, desaparece. El interruptor "Sugerencias de estudio autónomo" las oculta.\n\n'
        'Opciones de abajo:\n• Tarea: abre el formulario de tarea.\n'
        '• Ocio, Trabajo y Extracurricular: bloques semanales que la app respeta al buscar espacios libres. Puedes elegir varios días. Si la hora de inicio es igual o posterior a la de fin, verás un aviso y no se podrá guardar.\n'
        '• Cargar horario: Eliminar horario, Editar horario (incluye tus sesiones de estudio agendadas) y Cargar horario (PDF oficial).',
  ),
  (
    '5. Importar el PDF oficial',
    'Descarga el "Reporte de horario" de Academusoft 4.0 en PDF. En Cargar horario elige el archivo. CronoEdu reconoce materia, día, hora, salón y docente de cada clase y te muestra una vista previa para desmarcar lo que no corresponda. Las clases que terminan a las :59 se redondean a la hora siguiente.',
  ),
  (
    '6. Técnicas de estudio',
    'Pomodoro: 25 min de enfoque, 5 de descanso y 15 cada 4 ciclos.\n'
        'Flowtime: el cronómetro cuenta hacia arriba y tú decides cuándo terminar. Una sesión es válida desde los 10 minutos. Descanso: <25 min → 5, 25–50 → 8, 50–90 → 10, más de 90 → ¼ del tiempo estudiado. Desde las 2 horas te preguntamos cada hora "¿Sigues ahí?"; si no respondes en 1 minuto, el enfoque se cierra en ese punto y empieza el descanso.\n\n'
        'El ciclo se cierra al terminar u omitir el descanso. Estados del temporizador: Enfoque (anillo morado), Pausa (gris punteado), Descanso (verde) y Logro. Arriba ves los minutos estudiados hoy y tus ciclos.',
  ),
  (
    '7. Sugerencias de estudio',
    'Tus tareas pendientes en tarjetas, la más cercana a entregarse primero. Desliza a la derecha para la siguiente y a la izquierda para la anterior. Cada tarjeta indica fecha (con los días que faltan), descripción, tiempo estimado y próximo espacio libre. En "Material para estudiar" aparecen hasta 3 libros o atlas de las bibliotecas de la universidad relacionados con la materia, el tema y tu carrera, más 2 videos de YouTube y 3 artículos (Google Académico, SciELO y Wikipedia); tócalos para abrirlos (necesitas internet; los libros piden tu cuenta institucional). El check verde la completa y "Empezar a estudiar" te lleva a Técnicas con esa tarea activa.',
  ),
  (
    '8. Notificaciones',
    '30 minutos antes de cada hora sugerida recibes una notificación con tres botones: "Ver espacio" (abre la app en ese espacio), "Agendar" (lo agrega a tu horario) y "Procrastinar" (descarta la sugerencia). En Flowtime también llega el "¿Sigues ahí?". Se activan o desactivan en Perfil.',
  ),
  (
    '9. Recompensas: avatar y ranking',
    'Las bellotas son la moneda de CronoEdu y cada bellota ganada es también un punto del ranking. Se ganan así:\n'
        '• Ciclo completo de Pomodoro o Flowtime: 10 (solo si el enfoque duró al menos 10 min).\n'
        '• Cada 5 minutos de enfoque: 1.\n'
        '• Tarea completada: 15, y 10 más si la marcas antes de su fecha y hora de entrega. Cada tarea paga una sola vez.\n'
        '• Racha: el primer ciclo de cada día da 5 bellotas por cada día seguido estudiando (máximo 25).\n\n'
        'Cada 120 puntos subes un nivel; gastar bellotas no te quita puntos ni nivel.\n\n'
        'Mi avatar: elige animal, disfraces y gorros (fresa, rana, patito, osito, tiburón, dinosaurio, birrete, corona…), algo para la cara, un efecto (corazones, brillitos, batería baja o en llamas) y un fondo. Algunos piden un nivel mínimo y muestran un candado. Toca un extra tuyo para ponértelo o quitártelo.\n\n'
        'Ranking: podio y lista de esta semana (desde el lunes) o de todo el tiempo, con tu posición y los puntos que te faltan para pasar al siguiente. Mientras no hay base de datos, muestra las cuentas de este celular y estudiantes de ejemplo.',
  ),
  (
    '10. Cuenta y perfil',
    'Edita tu información, activa o desactiva las notificaciones, elige modo claro, oscuro o del sistema, abre esta ayuda, cierra sesión o elimina tu cuenta. Cerrar sesión conserva tus datos para la próxima vez. Eliminar la cuenta borra la cuenta, sus datos y su puesto en el ranking de este celular, y no se puede deshacer.',
  ),
];

class _ManualTab extends StatelessWidget {
  const _ManualTab();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final (title, body) in _manual)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
            ],
          ),
        ),
    ],
  );
}
