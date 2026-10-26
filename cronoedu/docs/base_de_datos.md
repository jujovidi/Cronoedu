# Base de datos (Supabase / PostgreSQL)

Hoy la app guarda todo en el celular con `shared_preferences`. Las pantallas no saben dónde se guardan los datos: usan `AuthRepository` (`lib/services/auth_repository.dart`) y `LeaderboardRepository` (`lib/services/leaderboard_repository.dart`). Para usar la base se escriben otras clases que cumplan esas interfaces (por ejemplo `SupabaseAuthRepository`) y se cambian en `lib/main.dart`.

La base es PostgreSQL en **Supabase**. La app no se conecta directo a PostgreSQL (la clave quedaría dentro del APK): habla con la API de Supabase con el paquete `supabase_flutter`, y las reglas de seguridad (RLS) de la base deciden qué puede leer o cambiar cada estudiante.

## Archivos

```
supabase/
  migrations/0001_esquema.sql   tablas, vistas del ranking, funciones de bellotas y permisos
  seed.sql                      catálogo de material (916) y objetos del avatar; lo genera
                                tool/generar_semilla_sql.dart (no editar a mano)
  local/simular_supabase.sql    lo mínimo de Supabase (auth.users, auth.uid(), roles) para probar
                                en un PostgreSQL normal
  local/pruebas.sql             pruebas: bellotas, compras, ranking y trampas bloqueadas
  local/probar_todo.sql         crea la base cronoedu_pruebas, carga todo y corre las pruebas
```

## Partes de la base

### 1. Catálogo de material de estudio (para las recomendaciones)
| tabla | qué guarda |
|---|---|
| `materiales` | id, fuente (ENI, AlphaCloud, Eureka, BioAtlas, BioAtlasVet), tipo, título, autores, año, subcategoría, URL y los tokens de búsqueda (`idx_titulo`, `idx_temas`, `idx_resumen`) |
| `material_programas` | carreras para las que sirve cada material |
| `sinonimos`, `stopwords` | lo que usa la búsqueda |
| `catalogo_version` | versión del catálogo, para que la app sepa si su copia está vieja |

Lo lee cualquiera, con o sin sesión; nadie lo cambia desde la app. La app puede seguir guardando su copia (`assets/data/material_estudio.json.gz`) para recomendar sin internet y descargar el catálogo solo cuando cambie `catalogo_version`.

### 2. Cuentas y gamificación
| tabla / vista | qué guarda |
|---|---|
| `auth.users` | la cuenta (correo y contraseña). La maneja Supabase Auth: registro, inicio de sesión y recuperación de contraseña por correo |
| `perfiles` | nickname (único sin importar mayúsculas), nombre, carrera, semestre, avatar, racha. Se crea solo al registrarse |
| `movimientos_bellotas` | cada bellota ganada o gastada, con motivo (`enfoque`, `ciclo`, `racha`, `tarea`, `tarea_a_tiempo`, `compra`) y fecha |
| `objetos_avatar`, `objetos_comprados` | la tienda (copia de `AvatarCatalog`) y lo que compró cada uno |
| `saldos` (vista) | bellotas disponibles, ganadas y nivel de cada estudiante |
| `ranking_total`, `ranking_semanal` (vistas) | nickname, avatar y puntos. El semanal cuenta desde el lunes (hora de Colombia), sin reiniciar nada a mano |

Cada estudiante solo ve su propio perfil y sus movimientos; del resto solo ve lo del ranking.

## Cómo la usa la app

| acción en la app | llamada |
|---|---|
| Registro | `auth.signUp(email:, password:, data: {'nickname': ...})`; antes, `rpc('nickname_disponible', {'p_nickname': ...})` |
| Inicio de sesión | `auth.signInWithPassword(email:, password:)` |
| Fin del enfoque | `rpc('ganar_enfoque', {'p_minutos': ...})` → bellotas ganadas |
| Fin del descanso | `rpc('ganar_ciclo')` → `{bellotas, bono_racha}` |
| Tarea completada | `rpc('ganar_tarea', {'p_tarea_id': ..., 'p_a_tiempo': ...})` → 0, 15 o 25 |
| Comprar en la tienda | `rpc('comprar_objeto', {'p_objeto': ...})` → saldo nuevo |
| Editar perfil o ponerse un objeto | `from('perfiles').update({...})` (solo nombre, carrera, semestre y avatar) |
| Ranking | `from('ranking_semanal').select()` o `from('ranking_total').select()` |
| Saldo y nivel | `from('saldos').select().single()` |

Las bellotas solo cambian con esas funciones, que aplican las reglas de `lib/services/rewards.dart`: 1 por cada 5 min de enfoque (máximo 16 h al día), 10 por ciclo si el enfoque duró 10 min o más, bono de racha de 5 por día (máximo 25), 15 por tarea y 10 más a tiempo (una vez por tarea), y compras con nivel y saldo suficientes. El avatar solo acepta objetos gratis o comprados. Si cambian las reglas de la app, hay que cambiarlas también en `0001_esquema.sql`.

El servidor no puede saber si el estudiante de verdad estudió los minutos que dice, ni si una tarea se entregó a tiempo (las tareas viven en el celular). Los topes evitan los abusos más obvios.

## Probar en el PC

Con PostgreSQL 18 instalado, desde la carpeta `cronoedu`:

```
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -f supabase/local/probar_todo.sql
```

Crea (o vuelve a crear) la base `cronoedu_pruebas`, carga el esquema y el catálogo y termina con `TODAS LAS PRUEBAS PASARON`. Si algo falla, se detiene en la línea `FALLÓ: ...`.

## Subir a Supabase

1. Crea un proyecto en supabase.com (plan gratis).
2. En **SQL Editor**, pega y ejecuta `supabase/migrations/0001_esquema.sql` y luego `supabase/seed.sql` (pesa ~800 KB; si el editor no lo acepta, usa `psql` con la cadena de conexión del proyecto). **No** ejecutes `supabase/local/simular_supabase.sql`: Supabase ya trae eso.
3. En **Project Settings → API** copia la URL del proyecto y la clave `anon` (es pública, va en la app). La clave `service_role` nunca va en la app.

Si se cambia el material de estudio: regenera el `.json.gz` con `tool/compactar_material.py`, luego `dart run tool/generar_semilla_sql.dart`, y vuelve a ejecutar `supabase/seed.sql`.

## Conectar la app

La app usa Supabase solo si recibe la URL y la clave publicable (Project Settings → API Keys) al compilar; sin ellas sigue funcionando todo en el celular, como antes. Están en `supabase/app_config.json` (la clave publicable es pública: va dentro de la app; la secreta nunca va aquí):

```
flutter run --dart-define-from-file=supabase/app_config.json
```

En VS Code, elige la configuración **CronoEdu (Supabase)** en Ejecutar y depurar (`.vscode/launch.json`) y presiona F5.

Proyecto actual: `cronoedu` en São Paulo (sa-east-1). Para conectarse con `psql` se usa el **Session pooler** (funciona en cualquier red): ver `supabase/subir.sql`.

- `lib/services/supabase_repositories.dart`: `SupabaseAuthRepository` (registro, inicio de sesión, borrar cuenta), `SupabaseLeaderboardRepository` (lee las vistas del ranking, 100 primeros) y `SupabaseBellotasRepository` (las funciones de bellotas y `mi_estado`).
- `lib/services/bellotas_repository.dart`: la interfaz que usa `AppState`.
- `AppState` sigue calculando las bellotas en el celular para mostrarlas al instante, manda cada acción al servidor en orden (enfoque → ciclo, compra → ponerse el objeto) y después reemplaza bellotas, racha, compras y avatar con lo que dice el servidor (`mi_estado`). Si el servidor rechaza algo (por ejemplo, una compra sin saldo), se deshace en el celular. Al abrir la app también trae el perfil, así que en un celular nuevo no se pide de nuevo el registro.
- Sin internet, lo ganado se ve en el celular pero **no queda en el servidor**: al volver la conexión, la siguiente lectura lo reemplaza. Guardar las acciones para mandarlas después queda pendiente.
- En Supabase, **Authentication → Sign In / Providers → Email**: si "Confirm email" está activo, al registrarse la app pide abrir el correo de confirmación antes de entrar. Para la exposición se puede desactivar.

## Pendiente

- Inicio de sesión con nickname: Supabase inicia sesión por correo. Buscar el correo de un nickname desde la app expondría los correos de todos, así que requiere una Edge Function. Mientras tanto, con Supabase la app pide el correo.
- Guardar las acciones hechas sin internet y mandarlas al volver la conexión.
- Las cuentas creadas en el celular no se migran: hay que registrarse de nuevo. Quitar los estudiantes de ejemplo (`includeDemo: false`).
- Opcional: tablas `tareas` y `bloques_horario` (las columnas de `Task.toJson()` y `ScheduleBlock.toJson()` más `usuario_id`) para tener el horario en varios dispositivos.
