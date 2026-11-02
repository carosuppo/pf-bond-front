# Revisión de la dependencia de foreground tracking

Fecha: 8 de octubre de 2026. Proyecto local pf-bond-front, rama existente fix/location. Sin operaciones Git ni acceso a GitHub. Investigación de versiones mediante documentación de pub.dev; resolución de paquetes offline.

## 1. PROBLEMA ENCONTRADO

Se habían copiado 97 archivos de flutter_foreground_task 11.0.2 para modificar un único bloque de RestartReceiver.kt. El objetivo era correcto: impedir que la recuperación usara alarmas exactas cuando Android las permite, incluida una exención de batería. Mantener todo el paquete en el repositorio no era necesario.

## 2. COMPORTAMIENTO DEL PLUGIN ORIGINAL

Se inspeccionaron la copia incluida y la versión original del caché local.

- RestartReceiver.setRestartAlarm calcula un PendingIntent explícito para su propio receiver.
- En Android 12+ y con canScheduleExactAlarms(context) verdadero utiliza AlarmManager.setAlarmClock. En los demás casos utiliza AlarmManager.set(RTC_WAKEUP, ...).
- No utiliza setExact ni setExactAndAllowWhileIdle en ese bloque; el problema concreto era setAlarmClock.
- ForegroundService.onDestroy programa recuperación a 5 segundos sólo con allowAutoRestart, detención incorrecta y stopWithTask false. Es una intención de tiempo, no una garantía de entrega.
- ForegroundService.onTaskRemoved programa recuperación a 1 segundo con stopWithTask false, independientemente de allowAutoRestart.
- El retorno START_STICKY depende de stopWithTask, no de allowAutoRestart. Una muerte abrupta puede no ejecutar onDestroy; Android decide cuándo recrear el servicio.
- Boot usa RebootReceiver, no una alarma de RestartReceiver. Respeta autoRunOnBoot, stopWithTask y la marca de detención explícita.
- No existe una opción pública 11.0.2 para imponer alarmas inexactas.

La versión posterior publicada consultada fue 11.0.3: su changelog describe un arreglo iOS/CocoaPods y la API pública sigue sin selector de exactitud. No hay una solución documentada que justifique actualizar; no se actualizó ni se descargó esa versión. No se afirma haber auditado su código Android.

Fuentes: [changelog](https://pub.dev/packages/flutter_foreground_task/changelog), [opciones públicas](https://pub.dev/documentation/flutter_foreground_task/latest/models_foreground_task_options/ForegroundTaskOptions-class.html).

## 3. ALTERNATIVAS ANALIZADAS

| Alternativa | Ventaja | Desventaja / decisión |
|---|---|---|
| A. Configuración oficial | Sería la solución de menor mantenimiento. | No hay selector de alarmas inexactas en 11.0.2. Descartada. |
| B. allowAutoRestart false + boot true | Conserva RebootReceiver y START_STICKY con stopWithTask false. | Quita el respaldo de onDestroy sin garantizar recuperación oportuna tras muerte del proceso; además NO elimina la alarma de onTaskRemoved. Descartada: no cumple la prohibición. |
| C. Receiver propio / manifest override | Podría parecer un cambio pequeño. | El PendingIntent es explícito y la programación sucede en el servicio original antes de la entrega. Deshabilitar/reemplazar el receptor no impide que se programe la alarma exacta. Cambiar también el servicio y sus referencias supondría un fork mayor; duplicar la clase produce conflictos. Descartada. |
| D. Parche reproducible en copia generada | Dependencia hosted normal, un bloque parcheado, caché intacto y mismos mecanismos nativos. | Requiere un hook de Gradle y revisar hashes al actualizar versión. Elegida. |
| E. Vendoring completo | Fácil de inspeccionar y autónomo una vez copiado. | 97 archivos mantenidos para una modificación muy pequeña. Descartada porque D fue validada. |

Mantener sólo boot y sustituir la recuperación es posible con modificaciones nativas, pero una solución propia necesita controlar también onTaskRemoved. El parche acotado conserva ambos caminos sin reimplementar el ciclo del servicio.

Un fork externo podría sustituir el hook en el futuro, si se mantuviera/publicara adecuadamente. No se creó ni se contactó ningún repositorio remoto.

## 4. SOLUCIÓN ELEGIDA

Dependencia hosted fijada exactamente en 11.0.2 + hook de Settings Gradle:

1. Flutter incluye el proyecto del plugin como de costumbre.
2. Antes de evaluar los proyectos Android, el hook verifica versión y SHA-256 normalizados de RestartReceiver.kt, ForegroundService.kt y RebootReceiver.kt.
3. Exige una sola coincidencia del bloque original. Si hay cambios inesperados, aborta; nunca continúa con el original inseguro.
4. Genera los inputs Android en `.dart_tool/bond_plugins/flutter_foreground_task-11.0.2-inexact-v1/android/` y reemplaza sólo el bloque de alarma por AlarmManager.set.
5. Redirige el ProjectDescriptor.projectDir a esa copia. Dart e iOS siguen resolviendo el paquete hosted original.
6. Sólo escribe archivos cuyo contenido cambió; no toca el Pub cache. No requiere un script manual posterior a pub get ni herramientas de parche externas.

.dart_tool ya está ignorado. La copia generada sobrevive a `gradlew clean` dentro de la misma invocación; Flutter clean la elimina y el siguiente build vuelve a crearla después de pub get. No hay receivers adicionales ni cambios de manifiesto.

El hook se aplica a builds Android debug y release. Se validó debug; no se ejecutó un build release.

API de Gradle utilizada: [ProjectDescriptor.projectDir desde Settings](https://docs.gradle.org/current/dsl/org.gradle.api.initialization.Settings.html). Al actualizar Flutter/Gradle o el plugin hay que revisar el hook; una opción oficial futura sería preferible y permitiría eliminarlo.

## 5. ARCHIVOS MODIFICADOS

Rutas relativas al frontend:

| Ruta | Cambio exacto |
|---|---|
| `pubspec.yaml` | Dependencia hosted `flutter_foreground_task: 11.0.2`, sin path ni rango ^. |
| `pubspec.lock` | source hosted, URL pub.dev, versión 11.0.2 y checksum publicado. |
| `android/settings.gradle.kts` | Aplica `gradle/foreground-task-inexact.gradle` tras incluir los proyectos Flutter. |
| `test/features/location/restart_alarm_policy_test.dart` | Verifica resolución hosted fijada, instalación del hook y aplicación única del parche sin llamadas de alarmas exactas. |
| `docs/BACKGROUND_LOCATION.md` | Actualiza arquitectura de dependencia y elimina inventario/documentación obsoletos de vendoring. |

Archivos nuevos:

- `android/gradle/foreground-task-inexact.gradle`: generación, verificación de integridad y parche mínimo.
- `docs/FOREGROUND_TASK_DEPENDENCY.md`: este informe y mantenimiento.

No se modificaron los servicios/providers/widgets de Bond, autenticación, backend, configuraciones de tracking ni manifiesto de la app durante esta revisión.

## 6. ARCHIVOS ELIMINADOS

Se elimina íntegramente `third_party/flutter_foreground_task/`: 97 archivos, incluido BOND_PATCH.md y su copia de LICENSE. La licencia del plugin permanece en la dependencia hosted. La copia Android temporal no es código propio versionado.

## 7. PUBSPEC

```yaml
flutter_foreground_task: 11.0.2
```

Se fija la versión porque los hashes y el parche están auditados para ella. pub get se ejecutó offline, usando el paquete ya disponible localmente. No hubo actualización de dependencias adicionales.

## 8. GOOGLE PLAY

| Elemento | Recuperación final de Bond |
|---|---|
| SCHEDULE_EXACT_ALARM | No declarado. |
| USE_EXACT_ALARM | No declarado. |
| REQUEST_IGNORE_BATTERY_OPTIMIZATIONS | No declarado ni solicitado automáticamente. |
| setExact | No invocado por la recuperación compilada. |
| setExactAndAllowWhileIdle | No invocado por la recuperación compilada. |
| setAlarmClock | No invocado por la recuperación compilada. |

El paquete hosted contiene la implementación original, pero NO es la fuente Android seleccionada para compilar. Hay que inspeccionar el receiver generado/compilado, no confundirlo con la copia original del caché. Se conserva AlarmManager.set, sujeto a Doze/App Standby y restricciones de inicio FGS. La configuración manual de batería se mantiene. La aprobación de Google Play continúa sujeta a su revisión, no se garantiza.

## 9. FUNCIONALIDAD

- Reboot: mismo RebootReceiver y autoRunOnBoot true, cuando Android lo permite.
- Process death: mismo START_STICKY y allowAutoRestart true; alarma de respaldo inexacta. Una muerte abrupta no garantiza onDestroy ni recuperación inmediata.
- Recientes: se conserva onTaskRemoved con recuperación inexacta y stopWithTask false.
- Apertura/resume/login: reconciliación existente intacta.
- Logout/sesión inválida/sharing deshabilitado: controles y detención existentes intactos.
- FGS location/notificación/background permission: intactos.
- Stream recovery/backoff/fallback GPS/timeout HTTP/401/403/disclosure/batería manual: intactos.

Se preserva el comportamiento conceptual del parche anterior; no se promete supervivencia indefinida frente a Android/OEM/force-stop. No se probaron reboot ni process death en teléfono físico en esta revisión.

## 10. TESTS

| Comando / comprobacion | Resultado | Tests aprobados/fallidos |
|---|---|---|
| flutter pub get --offline | Correcto: hosted 11.0.2, sin otras actualizaciones. | No aplica |
| flutter test --no-pub test/features/location/restart_alarm_policy_test.dart | Correcto. | 2 / 0 |
| flutter test --no-pub --reporter expanded | Suite completa correcta tras eliminar third_party. | 179 / 0 |
| flutter analyze --no-pub | Proyecto completo sin incidencias. | No aplica |
| flutter build apk --debug --no-pub | APK compilado con hook y dependencia hosted. | No aplica |
| dart format test/features/location/restart_alarm_policy_test.dart | Correcto. | No aplica |
| GradleWrapperMain --offline -p .dart_tool/bond_patch_negative_test help | El fixture con fuente alterada fue rechazado por SHA-256: fallo Gradle esperado, verificacion aprobada. | 1 guard aprobado |

Verificaciones adicionales: manifiesto combinado debug sin los tres permisos prohibidos; un solo FGS location y los dos receivers originales, sin duplicados. Inspeccion de bytecode con javap: solo AlarmManager.set en la programacion de recuperacion. Los hashes del Pub cache permanecieron identicos.

Se elimino la copia temporal generada, ya sin third_party, y se repitio flutter build apk --debug --no-pub: correcto (110,6 s). Gradle la regenero automaticamente. Comparacion del arbol nativo: solo RestartReceiver.kt difiere del paquete original. Bytecode y manifiesto se volvieron a verificar sobre ese APK final.

Las ejecuciones usan el snapshot del SDK instalado para evitar el wrapper .bat con problemas de acceso al caché. Ejemplo equivalente:

```powershell
$dartSdk = 'C:/Users/Usuario/Documents/flutter/bin/cache/dart-sdk/bin/dart.exe'
$flutterTool = 'C:/Users/Usuario/Documents/flutter/bin/cache/flutter_tools.snapshot'
& $dartSdk $flutterTool pub get --offline
& $dartSdk $flutterTool test --no-pub
& $dartSdk $flutterTool analyze --no-pub
& $dartSdk $flutterTool build apk --debug --no-pub
```

La primera compilación falló por un BOM de PowerShell en el script Groovy; se corrigió guardándolo en UTF-8 sin BOM. No fue un problema del enfoque de parche. El build mantiene un aviso previo de firebase_core/Kotlin sobre futuras versiones de Flutter.

## 11. RECOMENDACIÓN

A. La nueva solución es mejor y recomiendo conservarla.

Reduce el mantenimiento versionado a un hook con un bloque de sustitución y verificaciones explícitas. Conserva las rutas de recuperación del plugin, vuelve a pub.dev, no modifica cachés globales y evita actualizaciones silenciosas sobre código nativo no revisado. Cuando exista una opción oficial equivalente, reemplazar el hook por esa configuración.
