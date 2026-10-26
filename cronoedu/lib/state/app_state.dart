import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../models/avatar.dart';
import '../models/schedule_block.dart';
import '../models/task.dart';
import '../models/user_profile.dart';
import '../services/bellotas_repository.dart';
import '../services/leaderboard_repository.dart';
import '../services/planner.dart';
import '../services/rewards.dart';
import '../services/schedule_pdf_parser.dart';
import '../services/storage_service.dart';

/// Pestañas principales de la app.
enum AppTab { inicio, horario, tecnicas, sugerencias, recompensas }

/// Estado global: tareas, horario semanal y perfil. Todo se guarda
/// localmente; con [bellotasServer], las bellotas, la tienda y el perfil
/// también van al servidor, que tiene la última palabra.
class AppState extends ChangeNotifier {
  AppState(this._storage, {this.account, this.leaderboard, this.bellotasServer})
    : _tasks = _storage.loadTasks(),
      _blocks = _storage.loadBlocks(),
      _profile = _storage.loadProfile(),
      _dismissed = _storage.loadDismissedSync();

  final StorageService _storage;

  /// Cuenta con sesión abierta (null solo en pruebas sin inicio de sesión).
  final Account? account;
  final LeaderboardRepository? leaderboard;

  /// Servidor de bellotas (null = todo solo en el celular).
  final BellotasRepository? bellotasServer;
  final _uuid = const Uuid();
  final planner = const Planner();

  List<Task> _tasks;
  List<ScheduleBlock> _blocks;
  UserProfile _profile;
  Set<String> _dismissed;

  AppTab _tab = AppTab.inicio;
  String? _activeTaskId;
  Duration _lastFocus = Duration.zero;
  Reward? _focusReward;
  Reward? _lastReward;

  // ---------- Navegación ----------
  AppTab get tab => _tab;
  void selectTab(AppTab t) {
    _tab = t;
    notifyListeners();
  }

  /// Tarea con la que el usuario fue a "Técnicas de estudio".
  Task? get activeTask => _activeTaskId == null ? null : _tasks.where((t) => t.id == _activeTaskId).firstOrNull;

  void startStudying(Task task) {
    _activeTaskId = task.id;
    _tab = AppTab.tecnicas;
    notifyListeners();
  }

  void clearActiveTask() {
    _activeTaskId = null;
    notifyListeners();
  }

  // ---------- Perfil ----------
  UserProfile get profile => _profile;
  ThemeMode get themeMode => _profile.themeMode;

  void updateProfile({String? name, String? career, int? semester}) {
    if (name != null) _profile.name = name;
    if (career != null) _profile.career = career;
    if (semester != null) _profile.semester = semester;
    _saveProfile();
    _toServer(_sendProfile());
  }

  void setNotifications(bool enabled) {
    _profile.notificationsEnabled = enabled;
    _saveProfile();
  }

  void setThemeMode(ThemeMode mode) {
    _profile.themeMode = mode;
    _saveProfile();
  }

  void markTutorialSeen() {
    _profile.tutorialSeen = true;
    _saveProfile();
  }

  /// Suma minutos de enfoque al registro de hoy y da 1 bellota por cada 5 min.
  void logFocus(Duration focus) {
    final today = _dayKey(DateTime.now());
    if (_profile.studyDay != today) {
      _profile.studyDay = today;
      _profile.studyMinutesToday = 0;
    }
    _profile.studyMinutesToday += focus.inMinutes;
    _profile.totalStudyMinutes += focus.inMinutes;
    _lastFocus = focus;
    _focusReward = _earn(focus.inMinutes ~/ Rewards.focusMinutesPerBellota);
    _saveProfile();
    if (focus.inMinutes >= Rewards.focusMinutesPerBellota) _toServer((s) => s.earnFocus(focus.inMinutes));
  }

  int get studyMinutesToday {
    final today = _dayKey(DateTime.now());
    return _profile.studyDay == today ? _profile.studyMinutesToday : 0;
  }

  void setShowStudySuggestions(bool show) {
    _profile.showStudySuggestions = show;
    _saveProfile();
  }

  /// Cuenta el ciclo y, si el enfoque duró al menos 10 min, da bellotas
  /// (más el bono de racha en el primer ciclo del día).
  Reward addCycle({required bool pomodoro}) {
    if (pomodoro) {
      _profile.pomodoroCycles++;
    } else {
      _profile.flowtimeCycles++;
    }
    var reward = const Reward();
    if (_lastFocus.inMinutes >= Rewards.minCycleFocusMinutes) {
      final now = DateTime.now();
      final today = _dayKey(now);
      var bonus = 0;
      if (_profile.lastCycleDay != today) {
        final yesterday = _dayKey(now.subtract(const Duration(days: 1)));
        _profile.streakDays = _profile.lastCycleDay == yesterday ? _profile.streakDays + 1 : 1;
        _profile.lastCycleDay = today;
        bonus = Rewards.streakBonus(_profile.streakDays);
      }
      final earned = _earn(Rewards.cycle + bonus);
      // La recompensa del ciclo muestra también las bellotas del enfoque.
      final focus = _focusReward;
      reward = Reward(
        bellotas: Rewards.cycle + (focus?.bellotas ?? 0),
        streakBonus: bonus,
        newLevel: earned.newLevel ?? focus?.newLevel,
      );
      _toServer((s) => s.earnCycle());
    }
    _focusReward = null;
    _lastReward = reward;
    _saveProfile();
    return reward;
  }

  /// Recompensa del último ciclo (para la pantalla de logro).
  Reward? get lastReward => _lastReward;

  int get bellotas => _profile.bellotas;
  int get level => Rewards.levelFor(_profile.bellotasEarned);
  double get levelProgress => Rewards.levelProgress(_profile.bellotasEarned);
  int get toNextLevel => Rewards.toNextLevel(_profile.bellotasEarned);
  int get streakDays {
    final now = DateTime.now();
    final last = _profile.lastCycleDay;
    return last == _dayKey(now) || last == _dayKey(now.subtract(const Duration(days: 1))) ? _profile.streakDays : 0;
  }

  AvatarLook get avatar => _profile.avatar;
  bool owns(AvatarItem item) => _profile.ownedItems.contains(item.id);
  bool isEquipped(AvatarItem item) => _profile.avatar[item.slot] == item.id;
  bool isLocked(AvatarItem item) => level < item.level;

  /// Compra el objeto si hay bellotas y nivel suficiente, y se lo pone.
  bool buyItem(AvatarItem item) {
    if (owns(item) || isLocked(item) || _profile.bellotas < item.price) return false;
    _profile.bellotas -= item.price;
    _profile.ownedItems.add(item.id);
    _profile.avatar = _profile.avatar.withItem(item.slot, item.id);
    _saveProfile();
    final send = _sendProfile();
    _toServer((s) async {
      await s.buy(item.id);
      await send(s);
    });
    return true;
  }

  /// Se pone el objeto (si es un accesorio ya puesto, se lo quita).
  void toggleEquip(AvatarItem item) {
    if (!owns(item)) return;
    final remove = item.slot.optional && isEquipped(item);
    _profile.avatar = _profile.avatar.withItem(item.slot, remove ? null : item.id);
    _saveProfile();
    _toServer(_sendProfile());
  }

  // ---------- Servidor ----------
  /// Llamadas pendientes, en orden: el ciclo necesita que el enfoque ya esté
  /// registrado y la compra, antes de ponerse el objeto.
  Future<void> _serverQueue = Future.value();

  /// Manda la acción al servidor y luego trae lo que el servidor tiene, que
  /// reemplaza lo calculado en el celular. Si falla (sin internet o una regla
  /// del servidor), igual se corrige con lo del servidor en cuanto responda.
  void _toServer(Future<void> Function(BellotasRepository s) action) {
    final s = bellotasServer;
    if (s == null) return;
    _serverQueue = _serverQueue.then((_) async {
      try {
        await action(s);
      } catch (e) {
        debugPrint('Servidor de bellotas: $e');
      }
      await _pullFromServer(s);
    });
  }

  /// Trae bellotas, racha, compras y perfil del servidor (al abrir la app).
  Future<void> syncFromServer() {
    final s = bellotasServer;
    if (s == null) return Future.value();
    return _serverQueue = _serverQueue.then((_) => _pullFromServer(s));
  }

  Future<void> _pullFromServer(BellotasRepository s) async {
    final ServerProfile? p;
    try {
      p = await s.load();
    } catch (e) {
      debugPrint('Servidor de bellotas: $e'); // sin internet: queda lo local
      return;
    }
    if (p == null) return;
    _profile
      ..bellotas = p.bellotas
      ..bellotasEarned = p.bellotasEarned
      ..streakDays = p.streakDays
      ..lastCycleDay = p.lastCycleDay
      ..weekKey = currentWeekKey()
      ..weekPoints = p.weekPoints
      ..ownedItems = {...AvatarCatalog.freeIds, ...p.ownedItems}
      ..avatar = p.avatar;
    // En un celular nuevo el perfil llega del servidor (y salta el registro).
    if (p.name.isNotEmpty) {
      _profile
        ..name = p.name
        ..career = p.career
        ..semester = p.semester;
    }
    _storage.saveProfile(_profile);
    notifyListeners();
  }

  /// Envío del perfil tal como está ahora: si antes de mandarlo llega una
  /// lectura del servidor, no debe cambiar lo que el usuario eligió.
  Future<void> Function(BellotasRepository s) _sendProfile() {
    final name = _profile.name, career = _profile.career, semester = _profile.semester, avatar = _profile.avatar;
    return (s) => s.saveProfile(name: name, career: career, semester: semester, avatar: avatar);
  }

  /// Suma bellotas al saldo y al total ganado; avisa si se subió de nivel.
  Reward _earn(int amount) {
    if (amount <= 0) return const Reward();
    final before = level;
    _profile.bellotas += amount;
    _profile.bellotasEarned += amount;
    final week = currentWeekKey();
    if (_profile.weekKey != week) {
      _profile.weekKey = week;
      _profile.weekPoints = 0;
    }
    _profile.weekPoints += amount;
    return Reward(bellotas: amount, newLevel: level > before ? level : null);
  }

  static String _dayKey(DateTime d) => DateUtils.dateOnly(d).toIso8601String().substring(0, 10);

  void resetCycles() {
    _profile.pomodoroCycles = 0;
    _profile.flowtimeCycles = 0;
    _saveProfile();
  }

  /// Borra todos los datos locales y vuelve al registro inicial.
  Future<void> deleteAccount() async {
    await _storage.clearAll();
    _tasks = [];
    _blocks = [];
    _profile = UserProfile();
    _dismissed = {};
    _activeTaskId = null;
    _lastFocus = Duration.zero;
    _focusReward = null;
    _lastReward = null;
    _tab = AppTab.inicio;
    notifyListeners();
  }

  // ---------- Tareas ----------
  List<Task> get tasks => List.unmodifiable(_tasks);

  List<Task> tasksOn(DateTime day) =>
      _tasks.where((t) => DateUtils.isSameDay(t.dueDate, day)).toList()
        ..sort((a, b) => a.status.index.compareTo(b.status.index));

  /// Pendientes ordenadas por fecha de entrega (la más cercana primero).
  List<Task> get pendingByDueDate {
    final list = _tasks.where((t) => t.isPending).toList()
      ..sort((a, b) {
        final d = a.dueDate.compareTo(b.dueDate);
        return d != 0 ? d : b.complexity.level.compareTo(a.complexity.level);
      });
    return list;
  }

  Task addTask({
    required String subject,
    required DateTime dueDate,
    required TaskComplexity complexity,
    String topic = '',
    DayTime? dueTime,
    DeliveryMode delivery = DeliveryMode.virtual,
    String description = '',
  }) {
    final task = Task(
      id: _uuid.v4(),
      subject: subject.trim(),
      dueDate: DateUtils.dateOnly(dueDate),
      complexity: complexity,
      topic: topic.trim(),
      dueTime: dueTime,
      delivery: delivery,
      description: description.trim(),
    );
    _tasks.add(task);
    _saveTasks();
    return task;
  }

  void updateTask(Task task) {
    _saveTasks();
  }

  /// Cambia el estado. Completar una tarea por primera vez da bellotas
  /// (más si se entrega a tiempo); la recompensa se devuelve para mostrarla.
  Reward setTaskStatus(Task task, TaskStatus status) {
    task.status = status;
    final now = DateTime.now();
    task.completedAt = status == TaskStatus.completada ? now : null;
    var reward = const Reward();
    if (status == TaskStatus.completada) {
      if (_activeTaskId == task.id) _activeTaskId = null;
      if (_profile.rewardedTasks.add(task.id)) {
        final onTime = !now.isAfter(task.dueDateTime);
        reward = _earn(Rewards.task + (onTime ? Rewards.taskOnTime : 0));
        _storage.saveProfile(_profile);
        publishScore();
        _toServer((s) => s.earnTask(task.id, onTime: onTime));
      }
    }
    _saveTasks();
    return reward;
  }

  Reward toggleTask(Task task) => setTaskStatus(task, task.isPending ? TaskStatus.completada : TaskStatus.pendiente);

  void deleteTask(Task task) {
    _tasks.removeWhere((t) => t.id == task.id);
    if (_activeTaskId == task.id) _activeTaskId = null;
    _saveTasks();
  }

  /// Materias conocidas (del horario y de tareas previas) para autocompletar.
  List<String> get knownSubjects {
    final set = <String>{
      ..._blocks.where((b) => b.type == BlockType.clase).map((b) => b.title),
      ..._tasks.map((t) => t.subject),
    }..removeWhere((s) => s.isEmpty);
    return set.toList()..sort();
  }

  // ---------- Horario ----------
  List<ScheduleBlock> get blocks => List.unmodifiable(_blocks);

  /// Bloques semanales (se repiten) de un día de la semana.
  List<ScheduleBlock> blocksOn(int weekday) =>
      _blocks.where((b) => !b.isOneOff && b.weekday == weekday).toList()..sort((a, b) => a.start.compareTo(b.start));

  /// Todo lo que ocupa tiempo en una fecha: semanales + sesiones agendadas.
  List<ScheduleBlock> blocksForDate(DateTime day) =>
      _blocks.where((b) => b.appliesTo(day)).toList()..sort((a, b) => a.start.compareTo(b.start));

  /// Sesiones de estudio agendadas (de un solo día), próximas primero.
  List<ScheduleBlock> get scheduledSessions {
    final today = DateUtils.dateOnly(DateTime.now());
    return _blocks.where((b) => b.isOneOff && !b.date!.isBefore(today)).toList()..sort((a, b) {
      final d = a.date!.compareTo(b.date!);
      return d != 0 ? d : a.start.compareTo(b.start);
    });
  }

  /// Bloques que chocan con el rango indicado (para avisar al usuario).
  List<ScheduleBlock> conflictsWith(int weekday, DayTime start, DayTime end, {String? ignoreId}) =>
      _blocks.where((b) => b.id != ignoreId && !b.isOneOff && b.weekday == weekday && b.overlaps(start, end)).toList();

  void addBlocks({
    required BlockType type,
    required String title,
    required Iterable<int> weekdays,
    required DayTime start,
    required DayTime end,
    String room = '',
  }) {
    for (final d in weekdays) {
      _blocks.add(
        ScheduleBlock(
          id: _uuid.v4(),
          type: type,
          title: title.trim(),
          weekday: d,
          start: start,
          end: end,
          room: room.trim(),
        ),
      );
    }
    _saveBlocks();
  }

  void updateBlock(ScheduleBlock block) => _saveBlocks();

  void deleteBlock(ScheduleBlock block) {
    _blocks.removeWhere((b) => b.id == block.id);
    _saveBlocks();
  }

  /// "Eliminar horario": limpia por completo las actividades del horario.
  void clearSchedule({bool alsoTasks = false}) {
    _blocks.clear();
    if (alsoTasks) _tasks.clear();
    _saveBlocks();
    if (alsoTasks) _saveTasks();
  }

  /// Inserta las clases reconocidas del PDF. Si [replaceClasses], primero
  /// quita las clases existentes (deja ocio/trabajo/extracurricular).
  int importClasses(List<ParsedClass> classes, {bool replaceClasses = true}) {
    if (replaceClasses) _blocks.removeWhere((b) => b.type == BlockType.clase);
    for (final c in classes) {
      _blocks.add(
        ScheduleBlock(
          id: _uuid.v4(),
          type: BlockType.clase,
          title: c.title,
          weekday: c.weekday,
          start: c.start,
          end: c.end,
          room: c.room,
          teacher: c.teacher,
          group: c.group,
        ),
      );
    }
    _saveBlocks();
    return classes.length;
  }

  // ---------- Sugerencias ----------
  /// Horas sugeridas de estudio autónomo (1 h por día, próximos 7 días).
  List<StudySuggestion> get studySuggestions => planner.studySuggestions(_tasks, _blocks, dismissed: _dismissed);

  /// La próxima hora libre sugerida (para la campanita de Inicio).
  StudySuggestion? get nextSuggestion {
    final list = studySuggestions;
    return list.isEmpty ? null : list.first;
  }

  List<StudySuggestion> suggestionsOn(DateTime day) =>
      studySuggestions.where((s) => DateUtils.isSameDay(s.start, day)).toList();

  StudySuggestion? suggestionByKey(String key) => studySuggestions.where((s) => s.key == key).firstOrNull;

  /// Agenda la sugerencia en el horario como sesión de estudio de ese día.
  ScheduleBlock scheduleSuggestion(StudySuggestion s) {
    final block = ScheduleBlock(
      id: _uuid.v4(),
      type: BlockType.estudio,
      title: s.task == null ? 'Estudio autónomo' : 'Estudio: ${s.task!.subject}',
      weekday: s.start.weekday,
      start: DayTime(s.start.hour, s.start.minute),
      end: DayTime(s.end.hour, s.end.minute),
      date: DateUtils.dateOnly(s.start),
    );
    _blocks.add(block);
    _saveBlocks();
    return block;
  }

  /// "Procrastinar": descarta la sugerencia.
  void dismissSuggestion(StudySuggestion s) {
    _dismissed.add(s.key);
    _storage.saveDismissed(_dismissed);
    notifyListeners();
  }

  /// Relee los descartes hechos desde una notificación con la app cerrada.
  Future<void> refreshDismissed() async {
    _dismissed = await _storage.loadDismissed();
    notifyListeners();
  }

  FreeSlot? nextSlotFor(Task task) => planner.nextSlotFor(task, _blocks);
  String workloadHint(Task task) => planner.workloadHint(task, _blocks);
  List<FreeSlot> freeSlotsOn(DateTime day) => planner.freeSlotsOn(day, _blocks, after: DateTime.now());

  /// Fecha mínima permitida para tareas y actividades: hoy.
  static bool isPastDay(DateTime day) => DateUtils.dateOnly(day).isBefore(DateUtils.dateOnly(DateTime.now()));

  // ---------- Persistencia ----------
  void _saveTasks() {
    _storage.saveTasks(_tasks);
    notifyListeners();
  }

  void _saveBlocks() {
    _storage.saveBlocks(_blocks);
    notifyListeners();
  }

  void _saveProfile() {
    _storage.saveProfile(_profile);
    publishScore();
    notifyListeners();
  }

  /// Puntos para el ranking: las bellotas ganadas en total.
  int get points => _profile.bellotasEarned;
  int get weekPoints => _profile.weekKey == currentWeekKey() ? _profile.weekPoints : 0;

  /// Sube el puntaje y el avatar al ranking.
  Future<void> publishScore() async {
    final a = account, board = leaderboard;
    if (a == null || board == null) return;
    await board.publish(
      LeaderboardEntry(
        accountId: a.id,
        nickname: a.nickname,
        avatar: _profile.avatar,
        points: _profile.bellotasEarned,
        weekPoints: _profile.weekPoints,
        weekKey: _profile.weekKey,
      ),
    );
  }
}
