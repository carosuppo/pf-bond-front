# Robustez de ubicación en segundo plano de Bond

Fecha: 8 de octubre de 2026. Trabajo exclusivamente local. Los HEAD locales leídos indican `fix/location` en ambos proyectos, no `develop`. No se ejecutaron comandos Git, cambios de rama, commits ni operaciones GitHub. La referencia efectiva fue el contenido local encontrado.

## 1. ARCHIVOS MODIFICADOS

Rutas relativas a `Front/pf-bond-front`. Cada fila indica cambio y motivo.

| Ruta | Qué cambió y por qué |
|---|---|
| `lib/core/network/api_client.dart` | PUT autenticado usa el timeout HTTP existente de 20 s; evita publicaciones permanentemente bloqueadas. |
| `lib/core/storage/session_storage_service.dart` | Persiste un veto `location_tracking_suspended` en almacenamiento seguro; una detención no puede convertirse en autorización al reiniciar. |
| `lib/core/routes/navigation/post_auth_navigator.dart` | Elimina restauraciones de tracking dependientes de la pantalla o de cargar grupos. |
| `lib/features/auth/providers/auth_provider.dart` | Callbacks de sesión válida y fin de sesión; versiones invalidan restauraciones pendientes después de logout. |
| `lib/features/auth/services/auth_service.dart` | Detiene tracking, limpia sesión al cerrar aun sin red y distingue 401 de fallos temporales al restaurar; verifica que el token no haya cambiado durante la consulta. |
| `lib/main.dart` | Conecta autenticación con reconciliación y comparte una instancia serializada del servicio entre Provider y Riverpod. |
| `lib/features/location/constants/location_tracking_config.dart` | Fallback espaciado cada 5 minutos. |
| `lib/features/location/providers/location_provider.dart` | Permisos reales sin prompts al restaurar/resume; operaciones serializadas, guards de sesión, controles explícitos de Ajustes y detención antes de limpiar socket. |
| `lib/features/location/services/background_location_service.dart` | Boot habilitado, start/stop serializados, veto persistente y APIs de consulta/acceso manual a batería. |
| `lib/features/location/services/location_service.dart` | Separa permiso de disponibilidad GPS; stream background de 25 m, precisión high y consulta de respaldo limitada a 25 s, sin modificar navegación. |
| `lib/features/location/services/location_tracking_task_handler.dart` | Autoriza antes de GPS; recupera error/done/silencio; backoff; fallback; exclusión mutua; detención terminal y cancelación de retries. |
| `lib/features/location/widgets/group_info_sheet.dart` | Inserta controles de compartición y batería en la sección de información del grupo. |
| `pubspec.yaml` | Resuelve la misma dependencia 11.0.2 desde una copia local para impedir alarmas exactas internas. No agrega bibliotecas. |
| `pubspec.lock` | Registra ese origen local; conserva versión 11.0.2 y demás dependencias. |
| `test/features/location/background_location_service_test.dart` | Fake idempotente compatible con persistir stop aun cuando el proceso no está corriendo. |
| `test/features/location/location_session_reset_test.dart` | Reconciliación con sharing/permisos reales, concurrencia y logout durante respuesta pendiente; ubicación UI proviene del servicio. |
| `test/features/location/location_tracking_task_handler_test.dart` | Recuperación, fallback, autorización al arrancar y respuestas terminales/temporales. |
| `test/features/auth/auth_service_logout_test.dart` | Verifica limpieza local después de detener tracking y logout remoto. |
| `test/features/auth/session_state_cleanup_test.dart` | Mock 401 tipado; restauración independiente de grupos, conservación offline y carreras con logout. |

## 2. ARCHIVOS NUEVOS

| Ruta | Finalidad |
|---|---|
| `lib/features/location/widgets/location_sharing_controls.dart` | Switch de sharing, disclosure previo, accesos explícitos a permisos/GPS y batería opcional. Los grupos obligatorios conservan su contrato: para dejar de compartir con ellos se sale del grupo. |
| `test/features/location/location_sharing_controls_test.dart` | Comprueba que cancelar disclosure no solicite sharing y que batería nunca se abra automáticamente. |
| `test/features/location/restart_alarm_policy_test.dart` | Verifica que la dependencia resuelta sea la local y que el restart no invoque alarmas exactas ni variantes allow-while-idle. |
| `docs/BACKGROUND_LOCATION.md` | Informe, validaciones, checklist y protocolo manual reproducible. |
| `third_party/flutter_foreground_task/BOND_PATCH.md` | Procedencia y mantenimiento del parche nativo. |

La copia local contiene código y metadatos del plugin instalado, con licencia MIT preservada. No se descargó ni modificó el caché global. El único cambio de comportamiento respecto de esa copia es `RestartReceiver.kt`: reemplaza la rama `setAlarmClock` por `AlarmManager.set(RTC_WAKEUP, ...)` para todos los reinicios. El inventario individual de los archivos copiados figura al final.

## 3. REINICIO DEL CELULAR

Antes: `autoRunOnBoot: false`. Ahora: true; `allowAutoRestart: true`, `stopWithTask: false`, `autoRunOnMyPackageReplaced: false`. El plugin conserva START_STICKY y los receivers originales. Boot intenta levantar el servicio nativo; no autoriza GPS por sí mismo.

El nuevo isolate consulta veto local, token/expiración, permiso real always y `GET /location/sharing`. Si falta autorización se detiene. Si al arrancar no puede validar sharing por falta de red, permanece sin GPS y reintenta al siguiente tick de un minuto. Una vez autorizado, los PUT vuelven a validar la sesión y sharing en backend.

El manifiesto combinado debug fue inspeccionado: `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK`, `POST_NOTIFICATIONS`, y `RECEIVE_BOOT_COMPLETED` aportado por el plugin. Un solo RebootReceiver y un solo RestartReceiver del plugin; servicio no exportado con tipo location y stopWithTask false. No hizo falta modificar AndroidManifest.xml. El APK actual usa minSdk 24 y targetSdk 36.

Android 12+ limita inicios desde background; Android 14+ comprueba permisos al crear FGS. Ubicación desde background requiere el permiso background correspondiente. Android 15 restringe tipos de FGS desde boot, pero no equivale a prohibir universalmente el tipo location. Se conservan las comprobaciones y el manejo nativo de errores del plugin. No se promete recuperación ante force-stop, permisos revocados, bloqueo del fabricante o restricciones del sistema. Abrir Bond vuelve a reconciliar.

Fuentes: [restricciones de FGS](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start), [tipos de FGS](https://developer.android.com/develop/background-work/services/fgs/service-types), [Android 15](https://developer.android.com/about/versions/15/behavior-changes-15).

## 4. RECUPERACIÓN DEL GPS

- onError/onDone anulan la referencia, cancelan la suscripción y programan reconstrucción.
- Backoff 5, 10, 20, 40, 80 y máximo 120 segundos; vuelve a 5 s al recibir una posición del stream.
- Una suscripción, una reconstrucción y un timer como máximo. Destroy/stop cancelan retries y bloquean callbacks tardíos.
- Cinco minutos sin eventos del stream provocan un intento de reconstrucción en el tick correspondiente; un dispositivo quieto también puede no emitir por el filtro de distancia.
- Al inicio autorizado y después cada 5 minutos se consulta posición real con timeout nativo de 25 s, sin consultas simultáneas.
- Fallback y stream usan la misma función de publicación: mínimo 15 s y 5 m. Stream background filtra 25 m. Navegación conserva sus ajustes previos.
- Heartbeat de 1 minuto independiente y sin requests solapados; error GPS no lo cancela. Los intervalos son objetivos, no garantías frente a suspensión de Android.
- `capturedAt` sale del timestamp real de Geolocator, nunca del heartbeat. Sin movimiento suficiente no se republica artificialmente una posición.

La UI existente atenúa miembros según `lastSeenAt`. Conviene mostrar separadamente “dispositivo activo” y “posición capturada hace X”; este cambio no rediseña los marcadores.

## 5. RESTAURACIÓN DE LA APP

Login/restauración válida invocan reconciliación desde AuthProvider, antes de PostAuthNavigator y de cargar grupos. Resume refresca backend y permisos si hay una sesión activa en el provider. No abre Ajustes ni pide permisos silenciosamente.

Sharing efectivo + permiso always llevan a ensureRunning: consulta el servicio nativo y sólo inicia si falta. Sin sharing o con permisos insuficientes se detiene. start/stop están serializados y comparten instancia; restauraciones simultáneas comparten Future. Las versiones de sesión descartan respuestas posteriores a logout. La consulta GPS inicial de la UI fue eliminada para no duplicar la del TaskHandler.

## 6. SESIONES

401 en publicación/heartbeat: cancelar stream/retries y detener servicio. También se comprueba token inexistente o expiración local al iniciar y en cada tick. 403 con el mensaje actual exacto `No groups have effective location sharing enabled.`: misma detención. Otros 403 no se confunden con ese motivo.

Timeout, DNS, socket, desconexión o 5xx no desactivan permanentemente el tracking. PUT usa 20 s de timeout y se reintenta con muestras/ticks posteriores. Logout invalida operaciones pendientes, detiene servicio, limpia provider y sesión; si el servidor no está accesible, la sesión local igualmente se elimina. No se cambia la duración de las sesiones ni se inventa revocación remota offline.

El veto persistente es sólo una prohibición local. Nunca reemplaza sesión, permisos o sharing del backend. Un inicio autorizado desde la app puede levantarlo tras reconciliar nuevamente.

## 7. BATERÍA

Estrategia B. No se agregó REQUEST_IGNORE_BATTERY_OPTIMIZATIONS ni se invoca requestIgnoreBatteryOptimization(). Se utiliza openIgnoreBatteryOptimizationSettings(), sólo después de tocar “Batería y ubicación continua” en la información del grupo y confirmar “Abrir ajustes”. La opción aparece si hay sharing efectivo.

El diálogo explica que Android puede limitar ubicación tras períodos prolongados sin abrir Bond y que cambiar batería es opcional. “Ahora no” no cambia sharing ni limita la app. No hay prompts automáticos ni recordatorios insistentes. El servicio expone isIgnoringBatteryOptimizations y mayBeBatteryRestricted; el provider expone el segundo para futuras indicaciones de UI.

Detalle crítico: Android puede permitir alarmas exactas a una app exenta de batería incluso sin el permiso explícito. El plugin original 11.0.2 elegía setAlarmClock en ese caso tanto al destruir servicio como al quitar de recientes. Por eso se conserva localmente con un parche mínimo a alarmas INEXACTAS. No se solicita eludir Doze; no se añaden wake locks (se conserva la configuración ya existente del FGS) ni wifi locks.

Fuentes: [Doze y exclusiones de batería](https://developer.android.com/training/monitoring-device-state/doze-standby), [AlarmManager](https://developer.android.com/reference/android/app/AlarmManager).

## 8. GOOGLE PLAY

Checklist del flujo cambiado:

- Ubicación background sólo para sharing efectivo; no se añadió envío para publicidad o analytics.
- Solicitud de ubicación sólo tras acción de compartir y disclosure aceptado. Coarse/fine permiten la decisión del sistema sobre ubicación aproximada; always se requiere para continuidad y reinicio desde background.
- Se mantiene la notificación del FGS y su tipo location. Android 13+ permite al usuario negar notificaciones: esto afecta visibilidad en la bandeja, aunque Android conserva su superficie de servicios activos.
- Sharing deshabilitado, logout, sesión inválida o permiso insuficiente detienen tracking. Grupos obligatorios mantienen la opción de salir del grupo.
- No se abren Ajustes ni se pide exclusión de batería de forma silenciosa.
- Sin nuevos permisos de alto riesgo; sin overlays, Accessibility, Device Admin o alarmas exactas de recuperación.
- Alarmas de recuperación inexactas, sujetas a Doze/App Standby; no hay bypass.

La declaración de background location y del FGS location en Play Console debe describir compartir continuamente con miembros de grupos. El disclosure visible está implementado; la política de privacidad y Data Safety deben concordar con la recopilación/uso/retención reales del producto. No se editaron Play Console ni documentos legales externos. Debe comprobarse que ya reflejen este uso; actualizar si no lo hacen. La aprobación sigue sujeta a revisión de Google Play: no se afirma compatibilidad garantizada.

Fuente: [requisitos de ubicación en segundo plano](https://support.google.com/googleplay/android-developer/answer/9799150).

## 9. BACKEND

BACKEND MODIFICADO: NO.

Se revisaron controller, servicio, repositorio y autenticación de sesiones. SessionAuthGuard protege los tres endpoints. El repositorio de sesiones filtra revokedAt nulo y expiresAt futuro; token ausente/inválido produce 401. Ambos PUT comprueban sharing efectivo y retornan el 403 identificado. Current persiste última posición, capturedAt recibido y lastSeenAt; heartbeat sólo cambia lastSeenAt. No hicieron falta endpoints ni contratos nuevos.

## 10. TESTS

Los comandos Flutter se ejecutaron mediante el snapshot del SDK instalado para evitar el wrapper .bat bloqueado por permisos de caché. Equivalente reproducible en PowerShell desde la raíz frontend:

```powershell
$dartSdk = 'C:/Users/Usuario/Documents/flutter/bin/cache/dart-sdk/bin/dart.exe'
$flutterTool = 'C:/Users/Usuario/Documents/flutter/bin/cache/flutter_tools.snapshot'
& $dartSdk $flutterTool pub get --offline
& $dartSdk $flutterTool test --no-pub --reporter expanded
& $dartSdk $flutterTool analyze --no-pub
& $dartSdk $flutterTool build apk --debug --no-pub
```

| Comando equivalente | Resultado | Tests aprobados/fallidos |
|---|---|---|
| flutter pub get --offline | Correcto; cambia solamente el origen de flutter_foreground_task 11.0.2 a path local. | No aplica |
| flutter test --no-pub --reporter expanded | Suite completa con plugin parcheado: correcta. | 178 / 0 |
| flutter analyze --no-pub | Sin errores de Bond; 4 avisos info de APIs deprecadas en Dart original del plugin copiado (WillPopScope y Color.red/green/blue). | No aplica |
| flutter analyze --no-pub lib test | Sin incidencias. | No aplica |
| flutter build apk --debug --no-pub | Correcto con plugin nativo parcheado; APK en build/app/outputs/flutter-apk/app-debug.apk. | No aplica |

Se inspeccionó además el bytecode compilado de RestartReceiver$Companion con javap: invoca AlarmManager.set y no setAlarmClock/setExact.

Los cuatro avisos del plugin se conservaron visibles, sin silenciarlos ni modificar APIs ajenas al parche. El intento inicial de flutter --version mediante wrapper quedó bloqueado por su caché y se canceló; se utilizó el snapshot para las validaciones. Un primer intento de format desde el directorio padre no encontró rutas; se repitió correctamente dentro del frontend.

Se ejecutó dart format únicamente sobre los archivos Dart modificados/nuevos. Iteraciones intermedias detectaron y corrigieron mocks desactualizados, un argumento obsoleto, lints y temporización de los tests: ubicación+logout 32/6; ubicación+auth 36/8 (incluye errores de carga); TaskHandler 12/2 y luego 14/0; ubicación+auth 72/1 y luego 76/0; suite completa previa al parche nativo 177/0. No se consideran satisfactorias las iteraciones fallidas. Backend sin cambios: no se ejecutó npm test.

No se ejecutaron pruebas integradas en un teléfono físico. Compilar APK y pasar unit/widget tests no verifica por sí solo reboot, Doze o políticas OEM. El build avisa sobre Kotlin Gradle Plugin de firebase_core para futuras versiones de Flutter; no impidió compilar.

## 11. PRUEBAS MANUALES

Preparación: dispositivo Android 12, 13, 14 o 15 (repetir por versión/fabricante), backend de pruebas, dos usuarios miembros del mismo grupo. Instalar APK debug, iniciar sesión, abrir información del grupo, habilitar compartir, aceptar disclosure y conceder ubicación always desde Ajustes si Android lo requiere. Autorizar notificaciones para observar la notificación persistente. Usar grupos no obligatorios para comprobar el switch.

```powershell
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell dumpsys activity services com.example.bond_front
adb logcat -s ForegroundService RebootReceiver RestartReceiver flutter
```

Observar desde el segundo usuario coordenadas, capturedAt y lastSeenAt (`GET /location/group/<id>/members`). Moverse al menos 25 m; esperar más de 15 s. Para fallback esperar 5–6 minutos. Un heartbeat puede renovar lastSeenAt sin cambiar capturedAt; eso es correcto.

A. Compartir → Home/pantalla apagada → caminar → comprobar notificación y nuevas coordenadas desde el segundo usuario. No usar force-stop como sustituto de cerrar la pantalla.

B. Compartir → botón Recientes → deslizar Bond fuera de recientes → comprobar continuidad. Si el fabricante mata el proceso, observar intento de recuperación permitido; no hay plazo fijo para la alarma inexacta.

C. Compartir → ejecutar y desbloquear tras arrancar:

```powershell
adb reboot
adb wait-for-device
adb shell dumpsys activity services com.example.bond_front
```

Verificar notificación, autorización y nuevas posiciones. Si el sistema bloquea arranque, abrir Bond y verificar reconciliación sin prompts automáticos. Repetir con sharing deshabilitado y después de logout: no debe publicar.

D. Internet:

```powershell
adb shell svc wifi disable
adb shell svc data disable
# Esperar al menos dos heartbeats y desplazarse.
adb shell svc wifi enable
adb shell svc data enable
```

Verificar que no se haya deshabilitado sharing y que se recuperen publicaciones con movimiento o el siguiente fallback.

E. GPS (si el fabricante no admite el comando, usar el interruptor Ubicación de Ajustes):

```powershell
adb shell cmd location set-location-enabled false
# Esperar un minuto.
adb shell cmd location set-location-enabled true
```

Esperar recuperación del stream/backoff, o hasta el siguiente fallback. GPS apagado no equivale a permiso revocado y no borra sharing.

F. Permiso revocado:

```powershell
adb shell pm revoke com.example.bond_front android.permission.ACCESS_BACKGROUND_LOCATION
```

Android puede matar el proceso al revocar. Confirmar ausencia de nuevas publicaciones y que abrir Bond no solicite permisos ni abra Ajustes automáticamente. Restaurar always sólo desde una acción explícita y comprobar recuperación.

G. Sesión inválida: en la BD de PRUEBAS, reemplazar 42 por el usuario de pruebas activo y ejecutar en el cliente SQL:

```sql
UPDATE "UserSession"
SET "revokedAt" = NOW()
WHERE "userId" = 42 AND "revokedAt" IS NULL;
```

No cambiar sesiones de usuarios reales. En el siguiente PUT/heartbeat debe verse 401 y detenerse FGS/stream. No modificar duración de sesión. Volver a iniciar sesión para continuar pruebas.

H. Desactivar sharing en todos los grupos no obligatorios; salir de grupos obligatorios si los hay. Confirmar desaparición de notificación y ausencia de heartbeat/GPS. Desactivar sólo uno de dos grupos efectivos debe mantener servicio.

I. Logout → comprobar desaparición de notificación → `adb reboot` → no debe reaparecer sharing. Repetir logout sin conexión y luego reiniciar con Internet.

J. Batería: repetir A–E primero con optimización normal y luego desde el botón de Bond, aceptar “Abrir ajustes” y elegir manualmente Bond sin optimización. Registrar versión/OEM, tiempos de interrupción y recuperación, gaps de capturedAt/lastSeenAt y consumo. Rechazar el diálogo debe conservar sharing.

Doze/App Standby (dispositivo de pruebas):

```powershell
adb shell dumpsys battery unplug
adb shell dumpsys deviceidle force-idle
# Observar durante varios minutos: Android puede suspender red/timers.
adb shell dumpsys deviceidle unforce
adb shell dumpsys battery reset
adb shell am set-inactive com.example.bond_front true
adb shell am get-inactive com.example.bond_front
adb shell am set-inactive com.example.bond_front false
```

El sistema puede mantener activa una app con FGS. Registrar lo observado; no asumir que set-inactive reproduce un teléfono sin usar durante días. Para probar el límite de force-stop por separado, usar Ajustes → Forzar detención: recuperación requiere volver a abrir la app; no se intenta eludirlo.

## 12. LIMITACIONES

- Android y el fabricante deciden ejecución, entrega de boot y tiempos de START_STICKY/alarmas inexactas; no hay garantía de supervivencia indefinida.
- Force-stop, detención por el usuario, hibernación/revocación de permisos o restricciones OEM pueden exigir abrir Bond y/o restaurar permisos.
- GPS, red y almacenamiento desbloqueado deben estar disponibles para autorizar y publicar; los temporizadores no vencen puntualmente con CPU suspendida.
- Rechazar background location impide esta modalidad continua. Denegar notificaciones afecta la visibilidad de la notificación según Android.
- La exención manual de batería es opcional y no elimina todas las restricciones del sistema.
- Google Play revisa la justificación del uso background/FGS y la concordancia con privacidad y disclosures.

## 13. RESUMEN FINAL

1. Recuperación de reboot habilitada y autorizada antes de GPS.
2. Stream con error/done/silencio recuperables y backoff acotado.
3. Fallback GPS de 5 minutos, sin consultas ni publicaciones excesivas.
4. Timeout HTTP y heartbeat independiente, sin falsear capturedAt.
5. Reconciliación desde autenticación y resume, independiente de grupos/pantallas.
6. Serialización y guards frente a concurrencia y logout.
7. Detención por sesión, permiso o sharing inválidos y veto local persistente.
8. Controles explícitos, disclosure y batería manual opcional.
9. Misma versión del plugin con parche local para usar sólo alarmas de recuperación inexactas.
10. Backend y contratos intactos; tests, análisis, APK y protocolo manual documentados.

## Inventario individual de la dependencia local

Las rutas siguientes son relativas a `third_party/flutter_foreground_task/`. Son copias nuevas respecto del proyecto Bond. Salvo RestartReceiver.kt y BOND_PATCH.md, su contenido se conserva idéntico al origen local.

| Ruta | Finalidad |
|---|---|
| `analysis_options.yaml` | Metadatos, licencia o documentacion original preservados. |
| `android/build.gradle` | Implementacion/configuracion Android original, sin cambios. |
| `android/gradle/wrapper/gradle-wrapper.properties` | Implementacion/configuracion Android original, sin cambios. |
| `android/gradle.properties` | Implementacion/configuracion Android original, sin cambios. |
| `android/settings.gradle` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/AndroidManifest.xml` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/errors/ActivityNotAttachedException.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/errors/NotSupportedException.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/errors/PermissionRequestCancelledException.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/errors/ServiceAlreadyStartedException.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/errors/ServiceNotStartedException.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/FlutterForegroundTaskLifecycleListener.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/FlutterForegroundTaskPlugin.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/FlutterForegroundTaskPluginChannel.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/FlutterForegroundTaskStarter.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/MethodCallHandlerImpl.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/models/ForegroundServiceAction.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/models/ForegroundServiceStatus.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/models/ForegroundServiceTypes.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/models/ForegroundTaskData.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/models/ForegroundTaskEventAction.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/models/ForegroundTaskEventType.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/models/ForegroundTaskOptions.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/models/NotificationButton.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/models/NotificationContent.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/models/NotificationIcon.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/models/NotificationOptions.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/models/NotificationPermission.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/PreferencesKey.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/RequestCode.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/service/ForegroundService.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/service/ForegroundServiceManager.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/service/ForegroundTask.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/service/ForegroundTaskLifecycleListeners.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/service/NotificationPermissionCallback.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/service/NotificationPermissionManager.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/service/RebootReceiver.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/service/RestartReceiver.kt` | Parche nativo: recuperacion siempre inexacta. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/service/ServiceProvider.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/utils/ErrorHandleUtils.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/utils/ForegroundServiceUtils.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/utils/PluginUtils.kt` | Implementacion/configuracion Android original, sin cambios. |
| `android/src/main/kotlin/com/pravera/flutter_foreground_task/utils/TrackVisibilityUtils.kt` | Implementacion/configuracion Android original, sin cambios. |
| `BOND_PATCH.md` | Documentacion del parche de Bond. |
| `CHANGELOG.md` | Metadatos, licencia o documentacion original preservados. |
| `ios/flutter_foreground_task/Classes/FlutterForegroundTaskPlugin.h` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Classes/FlutterForegroundTaskPlugin.m` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Package.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/errors/ServiceError.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/FlutterForegroundTaskLifecycleListener.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/FlutterForegroundTaskPluginSPMBridge.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/FlutterForegroundTaskStarter.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/models/BackgroundServiceAction.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/models/BackgroundServiceStatus.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/models/ForegroundTaskData.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/models/ForegroundTaskEventAction.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/models/ForegroundTaskEventType.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/models/ForegroundTaskOptions.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/models/NotificationButton.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/models/NotificationContent.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/models/NotificationOptions.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/models/NotificationPermission.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/PreferencesKey.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/service/BackgroundService.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/service/BackgroundServiceManager.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/service/ForegroundTask.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/service/ForegroundTaskLifecycleListeners.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/service/NotificationPermissionManager.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task/SwiftFlutterForegroundTaskPlugin.swift` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task_early_registration/Flutterforegroundtaskearlyregistration.m` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task/Sources/flutter_foreground_task_early_registration/include/flutter_foreground_task_early_registration/Flutterforegroundtaskearlyregistration.h` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `ios/flutter_foreground_task.podspec` | Implementacion/metadatos iOS originales preservados; Bond usa Android. |
| `lib/errors/service_already_started_exception.dart` | API Dart original, sin cambios. |
| `lib/errors/service_not_initialized_exception.dart` | API Dart original, sin cambios. |
| `lib/errors/service_not_started_exception.dart` | API Dart original, sin cambios. |
| `lib/errors/service_timeout_exception.dart` | API Dart original, sin cambios. |
| `lib/flutter_foreground_task.dart` | API Dart original, sin cambios. |
| `lib/flutter_foreground_task_method_channel.dart` | API Dart original, sin cambios. |
| `lib/flutter_foreground_task_platform_interface.dart` | API Dart original, sin cambios. |
| `lib/models/foreground_service_types.dart` | API Dart original, sin cambios. |
| `lib/models/foreground_task_event_action.dart` | API Dart original, sin cambios. |
| `lib/models/foreground_task_options.dart` | API Dart original, sin cambios. |
| `lib/models/notification_button.dart` | API Dart original, sin cambios. |
| `lib/models/notification_channel_importance.dart` | API Dart original, sin cambios. |
| `lib/models/notification_icon.dart` | API Dart original, sin cambios. |
| `lib/models/notification_options.dart` | API Dart original, sin cambios. |
| `lib/models/notification_permission.dart` | API Dart original, sin cambios. |
| `lib/models/notification_priority.dart` | API Dart original, sin cambios. |
| `lib/models/notification_visibility.dart` | API Dart original, sin cambios. |
| `lib/models/service_options.dart` | API Dart original, sin cambios. |
| `lib/models/service_request_result.dart` | API Dart original, sin cambios. |
| `lib/task_handler.dart` | API Dart original, sin cambios. |
| `lib/ui/with_foreground_task.dart` | API Dart original, sin cambios. |
| `lib/utils/color_extension.dart` | API Dart original, sin cambios. |
| `lib/utils/utility.dart` | API Dart original, sin cambios. |
| `LICENSE` | Metadatos, licencia o documentacion original preservados. |
| `pubspec.yaml` | Metadatos, licencia o documentacion original preservados. |
