# Diagnóstico temporal del mapa de Bond

## Base reproducible

- Frontend local: `346adf6bf4f0cbc9d93d127c981eb646d35690b9`. Al comenzar, tanto `develop` como la rama activa `fix/performance` apuntaban a ese commit; el árbol estaba limpio. No se cambió de rama ni se consultó/actualizó el remoto.
- Flutter **3.44.4 stable**, framework `ad70ec4617166f1c38e5d2bfd388af71fda14f06`, engine `a10d8ac38de835021c8d2f920dbf50a920ccc030`, Dart **3.12.2**.
- `flutter_map` **8.3.1**, hash hosted del lock original `ce1debbb29cade61964334b2a19c7c76e5bb2ef7dacf126c6424ee44036232f8`.
- `vendor/flutter_map` contiene la biblioteca y metadatos/licencia de esa versión, copiados de la caché existente. Se omitieron ejemplos, tests y artefactos generados de la dependencia. La caché global no se editó.
- `pubspec_overrides.yaml` selecciona esa copia. El único cambio de resolución en `pubspec.lock` es hosted → path para la misma versión. No se actualizaron dependencias.
- `.env`, configuración Android, backend y credenciales se conservaron. No hubo push, PR ni instalación de APK.

## Qué registra

Activación exclusiva con `--dart-define=BOND_MAP_DIAGNOSTICS=true`; sin esa opción no se crea el propietario, timer ni callback de cámara. Los guards de la biblioteca también quedan desactivados.

- Cámara: timestamp UTC, tipo/fuente de evento, zoom, centro, viewport sin rotación, tamaño efectivo, rotación y cantidades de miembros, clusters, POI y ruta. Miembros incluye el marcador propio cuando está presente; clusters incluye grupos unitarios. Las cantidades corresponden al último build. No se registran nombres, IDs, fotos, URLs ni payloads.
- Historial compartido de **24 muestras**, muestreo máximo de cámara cada **250 ms por mapa** y tiles cada **250 ms**. Las anomalías omiten el muestreo para conservar operandos inválidos. Un último estado de cámara por propietario permite correlación en los registros periódicos, incluso si no hay excepción.
- Tiles: zoom de cámara y de cálculo, zoom nativo de tiles, centro geográfico utilizado y de cámara, centro proyectado antes de redondear, tamaño, escala, límites en píxeles y valores de columna X/fila Y para cada borde antes de floor/ceil. En una falla anterior, los valores todavía no calculados se etiquetan `not_computed`.
- Puntos instrumentados: `zoom.round()` en build/eventos/carga y clamp; centro proyectado antes de `.floor()`; cálculo completo antes de `DiscreteTileRange`; operandos de `fromPixelBounds` inmediatamente antes de floor/ceil. El `.floor()` del centro usa `floorToDouble` en esta versión; también se observa para capturar propagación de valores inválidos.
- Máximo **6 volcados por proceso**, como mínimo **10 segundos entre repeticiones de una misma etapa**. Etapas distintas pueden volcar consecutivamente para no perder los operandos de tiles después de una anomalía de cámara. Máximo global de **2400 líneas nuevas de diagnóstico por proceso**. Reiniciar la app reinicia esos límites. Los mensajes originales de Flutter no se suprimen.
- Cada **5 segundos por mapa montado**: bytes/entradas retenidas de ImageCache, imágenes vivas y pendientes. Timer cancelado en `dispose`; no se agrega ninguna suscripción al tracking. ImageCache es global, de modo que mapas simultáneos muestran el mismo cache.

Las coordenadas llevan `sensitive_coordinates`: son datos sensibles de la prueba. No publicar capturas sin revisarlas. ImageCache **no representa memoria total**, heap Dart, PSS ni RSS. El script obtiene PSS/RSS de Android, en kB según `dumpsys`; dividir por 1024 para MiB. El crecimiento fuera del cache puede requerir luego perfiles de heap/nativo/GPU. Este parche no atribuye causalidad al backend ni supone que la excepción explica toda la memoria acumulada.

## Compilar y ejecutar en Android físico

Desde la raíz del frontend, conservar la configuración existente y verificar que el SDK coincide:

```powershell
flutter --version
flutter pub get --offline
flutter devices
flutter build apk --profile --no-pub --dart-define=BOND_MAP_DIAGNOSTICS=true --dart-define=BOND_FRONTEND_COMMIT=346adf6bf4f0cbc9d93d127c981eb646d35690b9
```

El APK esperado es `build/app/outputs/flutter-apk/app-profile.apk`. Ya se generó localmente una variante **profile ARM64** con diagnóstico activado; hash y comando offline exacto en `VALIDATION.md`. La compilación no lo instala.

Si el dispositivo es ARM64 (`adb shell getprop ro.product.cpu.abi` devuelve `arm64-v8a`), agregar `--target-platform android-arm64` al comando `flutter build apk` permite empaquetar solo esa arquitectura. En esta máquina faltan los JAR profile de ARM32 y x86_64 para el build universal; ver `VALIDATION.md`.

Para ejecutar **vos** en el teléfono físico autorizado (este comando sí instala/inicia):

```powershell
flutter run --profile --no-pub -d ID_DEL_DISPOSITIVO --dart-define=BOND_MAP_DIAGNOSTICS=true --dart-define=BOND_FRONTEND_COMMIT=346adf6bf4f0cbc9d93d127c981eb646d35690b9
```

Si la caché no contiene todas las dependencias, usar `flutter pub get` con acceso a ellas; no `pub upgrade`. No cambiar backend entre muestras de una misma prueba. Registrar por separado la revisión desplegada conocida (sin URL ni secretos), dispositivo/Android, escenario y hora UTC de inicio del gesto. Repetir primero con tres miembros cercanos y zoom intenso; luego el control con un miembro, manteniendo las demás condiciones. Para otra variante de backend, iniciar una captura y proceso nuevos, sin concluir causalidad solo por esa comparación.

## Capturar

En otra terminal, iniciar antes de abrir el mapa:

```powershell
.\diagnostics\Capture-MapMemory.ps1 -Adb "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -Serial ID_DEL_DISPOSITIVO -IntervalSeconds 5 -Minutes 30
```

Puede omitirse `-Serial` si hay un único dispositivo. No inicia Bond ni instala APK. Detener con **Q** o **Ctrl+C** en una consola PowerShell interactiva. `finally` cierra el escritor y termina únicamente su proceso logcat. Cada comando meminfo tiene timeout de 10 s; la separación real puede superar 5 s si adb demora.

Si PowerShell bloquea scripts locales por su política predeterminada, se puede ejecutar este script revisado en un proceso puntual sin cambiar la política global:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\diagnostics\Capture-MapMemory.ps1 -Adb "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -Serial ID_DEL_DISPOSITIVO
```

Salida en `diagnostics/captures/FECHA-HORA/`: `metadata.txt` con relojes host/dispositivo, `timeline.txt` con PID y UTC, `logcat.txt` y un `meminfo-UTC.txt` por muestra. Captura limitada a 30 minutos por defecto (máximo configurable 120) y aproximadamente 32 MiB de logcat. No limpia el buffer del dispositivo. Conserva solo BOND_DIAG, la excepción numérica/frames de tiles y líneas seleccionadas de ANR/muerte/lmkd de Bond; omite otros logs Flutter que podrían contener datos del backend. No es un logcat forense completo. Algunos fabricantes no exponen lmkd por adb sin permisos adicionales. Continúa muestreando cuando desaparece el PID, para documentar la terminación.

Correlacionar `ANOMALY` y `HISTORY` con la muestra meminfo anterior/posterior del **mismo PID**, no con otro proceso reiniciado. Buscar primero el primer operando no finito y su etapa; observar también si la memoria crecía antes de eso. Los 24 registros son una ventana muestreada, no todos los frames. Al agotarse el límite de volcados/líneas, reiniciar el proceso para una nueva prueba.

## Validaciones

Ver `VALIDATION.md` para resultados de esta ejecución. Comandos repetibles:

```powershell
flutter analyze --no-pub
flutter test --no-pub test/features/location
flutter test --no-pub --dart-define=BOND_MAP_DIAGNOSTICS=true test/features/location/map_diagnostics_test.dart
```

## Retirar solo la instrumentación

Para desactivarla sin retirar el parche, recompilar **sin** `BOND_MAP_DIAGNOSTICS=true` (no alcanza con reiniciar un APK ya compilado con la opción).

Para retirarla del árbol, revisar primero cualquier trabajo posterior. `tracked-changes.patch` contiene únicamente las adiciones de instrumentación a `location_map.dart` y el cambio de origen en `pubspec.lock`:

```powershell
git apply --reverse --check diagnostics/tracked-changes.patch
git apply --reverse diagnostics/tracked-changes.patch
```

Si `--check` falla, detenerse y retirar esos hunks manualmente; no usar reset/restore global ni `git clean`. Después eliminar **solo si no tienen cambios posteriores propios**: `lib/features/location/services/map_diagnostics.dart`, `test/features/location/map_diagnostics_test.dart` y `pubspec_overrides.yaml`. Si agregaste otros overrides, quitar solo el de flutter_map. Ejecutar `flutter pub get --offline` para volver a la dependencia hosted original.

Finalmente archivar o eliminar la carpeta `diagnostics` después de preservar las capturas deseadas y comprobar que no contiene trabajo nuevo. `baseline/location_map.dart.txt` y `baseline/pubspec.lock` son copias previas de referencia; no copiarlas encima de archivos que hayan recibido trabajo posterior. La rama y los demás archivos no necesitan restauración.
