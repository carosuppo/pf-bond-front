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
| `pubspec.yaml` | Resuelve flutter_foreground_task 11.0.2 desde pub.dev, fijado exactamente; Gradle aplica el parche Android reproducible. |
| `pubspec.lock` | Registra source hosted y checksum de pub.dev; conserva version 11.0.2 y las demas dependencias. |
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
| `test/features/location/restart_alarm_policy_test.dart` | Verifica dependencia hosted fijada, hook instalado y reemplazo unico de la programacion exacta. |
| `docs/BACKGROUND_LOCATION.md` | Informe, validaciones, checklist y protocolo manual reproducible. |
| `android/gradle/foreground-task-inexact.gradle` | Parche Android reproducible, verificado por version y hashes, sin modificar el Pub cache. |
| `docs/FOREGROUND_TASK_DEPENDENCY.md` | Revision de alternativas y mantenimiento del hook de Gradle. |

La dependencia vuelve a pub.dev con version exacta 11.0.2. El hook de Settings genera los inputs nativos en .dart_tool/bond_plugins/ y aplica solamente la sustitucion por AlarmManager.set. No se conserva third_party/flutter_foreground_task. Ver [revision de la dependencia](FOREGROUND_TASK_DEPENDENCY.md) para los archivos modificados/eliminados en esta limpieza.

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

Detalle crítico: Android puede permitir alarmas exactas a una app exenta de batería incluso sin el permiso explícito. El plugin original 11.0.2 elegía setAlarmClock en ese caso tanto al destruir servicio como al quitar de recientes. Por eso Gradle aplica un parche minimo sobre una copia Android generada, usando solo alarmas INEXACTAS; el paquete sigue resolviendo desde pub.dev. No se solicita eludir Doze; no se añaden wake locks (se conserva la configuración ya existente del FGS) ni wifi locks.

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

La validacion vigente, despues de reemplazar el vendoring por el hook de Gradle, esta detallada en [FOREGROUND_TASK_DEPENDENCY.md](FOREGROUND_TASK_DEPENDENCY.md):

- flutter pub get --offline: dependencia hosted 11.0.2.
- flutter test --no-pub: 179 aprobados, 0 fallidos.
- flutter analyze --no-pub: sin incidencias en el proyecto completo.
- flutter build apk --debug --no-pub: APK compilado.
- Verificacion del manifiesto, bytecode de recuperacion y rechazo de fuentes inesperadas.

No se ejecutaron pruebas integradas en un telefono fisico. Compilar APK y pasar tests no verifica por si solo reboot, Doze o politicas OEM. El build conserva el aviso previo de firebase_core/Kotlin sobre futuras versiones de Flutter.

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
9. Misma version hosted del plugin con parche reproducible de Gradle para usar solo alarmas de recuperacion inexactas.
10. Backend y contratos intactos; tests, análisis, APK y protocolo manual documentados.

