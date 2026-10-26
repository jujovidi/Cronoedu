# CronoEdu

App Flutter para estudiantes universitarios: calendario de tareas, horario semanal, técnicas de estudio (Pomodoro y Flowtime) y sugerencias según tus espacios libres. Todos los datos se guardan solo en el celular.

## Cómo ejecutarla (VS Code + emulador de Android Studio)

1. Instala o actualiza Flutter (estable 3.47 o superior): `flutter upgrade`. Verifica con `flutter doctor`.
2. En VS Code instala las extensiones **Flutter** y **Dart**.
3. Abre la carpeta `cronoedu` en VS Code (Archivo → Abrir carpeta).
4. En una terminal dentro de la carpeta: `flutter pub get`.
5. Abre Android Studio → Device Manager y arranca un emulador (por ejemplo Pixel 7, API 34 o superior).
6. En VS Code, abajo a la derecha, elige el emulador como dispositivo y presiona **F5** (o `flutter run`).

Para probar la importación del horario en el emulador, arrastra tu `reporteHorario.pdf` encima de la ventana del emulador: queda en la carpeta Descargas y luego lo eliges desde Calendario → Cargar horario → Cargar horario.

## Pruebas

```
flutter test
```

Incluye el lector del PDF con un reporte de ejemplo (`test/reporteHorario_ejemplo.pdf`) y un recorrido por todas las pantallas. Las capturas de `docs/capturas/` se generan con `CAPTURAS=1 flutter test --update-goldens` (en las capturas de prueba algunos textos salen como bloques y las sombras como bordes negros; en el celular se ven normales).

## Estructura

```
lib/
  main.dart                     arranque, tema claro/oscuro, idioma español
  theme/app_theme.dart          paleta de la propuesta (morado, naranja, azul, verde, grafito)
  models/                       Task, ScheduleBlock, UserProfile, Account, Avatar (catálogo de la tienda)
  state/app_state.dart          estado global y guardado local por cuenta
  state/auth_controller.dart    sesión abierta, registro e inicio de sesión
  state/study_timer.dart        temporizador de 4 estados (enfoque, pausa, descanso, logro)
  services/
    notification_service.dart   notificaciones del sistema (sugerencias y "¿Sigues ahí?")
    storage_service.dart        guardado local (shared_preferences), separado por cuenta
    auth_repository.dart        cuentas (interfaz + versión local)
    password_hasher.dart        hash PBKDF2 de contraseñas
    leaderboard_repository.dart ranking semanal y total (interfaz + versión local)
    study_material_repository.dart catálogo y búsqueda del material de estudio
    planner.dart                detecta espacios libres y estima carga de cada tarea
    rewards.dart                reglas de bellotas, racha y niveles
    schedule_pdf_parser.dart    reconoce el reporteHorario de Academusoft 4.0
    pdf_schedule_importer.dart  extrae el texto del PDF (Syncfusion)
  screens/                      inicio de sesión, inicio, calendario/horario, técnicas, sugerencias,
                                recompensas (avatar y ranking), perfil, ayuda
  widgets/                      calendario, cuadrícula semanal, formularios, anillo del temporizador,
                                avatar_view.dart (pixel art de animales, disfraces y efectos)
assets/images/                  poses del mapache
assets/data/                    catálogo de material de estudio (gzip)
tool/compactar_material.py      genera ese catálogo
```

## Cómo se lee el horario oficial

El PDF de Academusoft trae una tabla, pero su texto no conserva las columnas. El lector toma la posición de cada palabra: la columna del día sale de la coordenada X de los encabezados Lunes…Domingo y la materia, de la fila en la que cae la franja horaria. De cada clase obtiene materia, día, hora, salón y docente. Las horas que terminan en :59 se redondean (11:00-12:59 queda 11:00-13:00). Antes de guardar se muestra una vista previa para desmarcar los grupos que no tomas (por ejemplo, las líneas de profundización).

## Notificaciones

Usa `flutter_local_notifications`. Al entrar por primera vez la app pide permiso de notificaciones (Android 13+). Avisa 30 minutos antes de cada hora sugerida de estudio, con los botones Ver espacio, Agendar y Procrastinar, y en Flowtime manda el "¿Sigues ahí?" desde las 2 horas. En el emulador, si no ves el aviso, revisa Ajustes → Apps → CronoEdu → Notificaciones. Los avisos programados son "inexactos" (Android puede retrasarlos unos minutos para ahorrar batería).

Si al compilar aparece un error de *desugaring*, revisa que `android/app/build.gradle.kts` conserve `isCoreLibraryDesugaringEnabled = true` y la dependencia `desugar_jdk_libs`.

## Reglas de estudio

- Sugerencias: una hora por día (los próximos 7 días) en el primer espacio libre entre 7:00 y 22:00, solo mientras haya tareas pendientes. Procrastinar descarta la del día; agendar la guarda como sesión de "Estudio autónomo" de ese día.
- Flowtime: sesión válida desde 10 min; "¿Sigues ahí?" a las 2 h y luego cada hora (1 min para responder); descanso de 5/8/10 min o ¼ del tiempo si pasa de 90 min; el ciclo se cierra al terminar el descanso.

## Material de estudio

Las Sugerencias de estudio muestran hasta 3 libros o atlas relacionados con cada tarea, sacados de las bibliotecas digitales de la universidad (ENI, Alpha Editorial Cloud, Eureka, BioAtlas y BioAtlasVet, 916 materiales). El catálogo viene dentro de la app en `assets/data/material_estudio.json.gz` (165 KB comprimido, solo los campos que se usan), así que buscar no necesita internet ni base de datos; abrir el enlace sí necesita internet y la cuenta institucional.

- Búsqueda: `lib/services/study_material_repository.dart` (la misma de `material_estudio/buscar.py`). La materia y el tema pesan más que la descripción, se ignoran los números sueltos ("Taller 3") y el material de la carrera del perfil sube un 30 %. Solo se muestran coincidencias claras (puntaje 12 o más).
- Videos y artículos (`lib/services/study_links.dart`): por cada tarea, 2 búsquedas de YouTube (explicación y ejercicios resueltos) y 3 de artículos (Google Académico, SciELO y Wikipedia) con la materia y el tema, sin palabras como "taller" o "parcial" ni números. Son búsquedas armadas, no videos fijos: no necesitan clave de API ni internet para armarse y siempre muestran resultados actuales.
- Los libros de ENI no traen enlace hasta poner la dirección de la biblioteca ENI de la universidad en `StudyMaterialLibrary.eniBaseUrl`.
- Para actualizar el catálogo: regenera la base en `material_estudio/` y luego, desde `cronoedu`, `python3 tool/compactar_material.py RUTA/material_estudio.json RUTA/sinonimos.json`.

## Cuenta e inicio de sesión

Al abrir la app se inicia sesión con correo o nickname y contraseña, o se crea una cuenta con nickname (el que aparece en el ranking), correo y contraseña.

- Nickname: 3 a 15 caracteres (letras, números, `_` y `.`), único sin importar mayúsculas.
- Contraseña: mínimo 8 caracteres con letras y números. Nunca se guarda en texto: se guarda un hash PBKDF2-HMAC-SHA256 con sal aleatoria (`lib/services/password_hasher.dart`).
- Cada cuenta tiene sus propias tareas, horario y perfil (claves `u:<id>:...`). La primera cuenta creada en el celular se queda con los datos que ya existían de versiones anteriores.
- Por ahora todo vive en el celular. Las pantallas solo hablan con las interfaces `AuthRepository` y `LeaderboardRepository`; para pasar a base de datos basta escribir otra implementación (ver `docs/base_de_datos.md`).

## Recompensas: avatar y ranking

El apartado **Recompensas** (menú Apartados, o desde el perfil) reúne el nivel, la racha, las bellotas, la tienda del avatar y el ranking. El saludo de Inicio quedó simple: foto de perfil y tareas pendientes.

En Técnicas la mascota acompaña el temporizador: en Pomodoro se come un tomate (por el reloj de cocina) y lo termina a los 25 minutos; en Flowtime estudia con un libro y la batería al 100 % y en el descanso se acuesta a dormir (`TomatoMascot`, `StudyingMascot` y `SleepingMascot` en `lib/widgets/mascot.dart`).

Los avatares son pixel art dibujado en código (`lib/widgets/avatar_view.dart`, cuadrícula de 32×32 con contorno negro y mejillas): mapache, gato, zarigüeya, pato, shiba, capibara, gato negro y panda, con disfraces (fresa, rana, patito, osito, tiburón, dinosaurio), gorros, cosas para la cara, efectos (corazones, brillitos, batería baja, en llamas) y fondos. Cualquier objeto sirve en cualquier animal; agregar uno es sumar una entrada en `AvatarCatalog` y su dibujo. La mascota de la app usa el mismo motor.

- Ciclo completo: 10 bellotas si el enfoque duró al menos 10 min. Además, 1 por cada 5 min de enfoque.
- Tarea completada: 15, y 10 más si es antes de su fecha y hora de entrega. Cada tarea paga una sola vez.
- Racha: el primer ciclo de cada día da 5 por cada día seguido (máximo 25).
- Nivel: uno cada 120 bellotas ganadas. Gastar no baja de nivel. Algunos objetos piden nivel mínimo.
- Ranking: los puntos son las bellotas ganadas (gastarlas no resta). Hay vista "Esta semana" (se reinicia cada lunes) y "Todo el tiempo", con podio para los 3 primeros. Mientras no haya base de datos se muestran 9 estudiantes de ejemplo junto a las cuentas creadas en el celular.

## Pendiente para siguientes versiones

- Ajustar duraciones de Pomodoro y el rango horario de estudio (hoy 7:00 a 22:00).
- Cuentas, bellotas y ranking ya pueden ir a Supabase (ver `docs/base_de_datos.md`); falta crear el proyecto, el inicio de sesión con nickname y la recuperación de contraseña desde la app.
