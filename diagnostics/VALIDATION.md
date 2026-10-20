# Validación local

- `flutter pub get --offline`: correcto; ninguna versión cambió, solo el origen local de flutter_map 8.3.1.
- `dart format` sobre los siete archivos Dart nuevos/modificados: correcto, última pasada sin cambios.
- `flutter analyze --no-pub`: correcto, sin incidencias.
- `flutter test --no-pub test/features/location`: **40 pruebas aprobadas**.
- Pruebas específicas `map_diagnostics_test.dart`, con diagnóstico **activado** y **desactivado**: **3/3 aprobadas en cada modo**, incluyendo una nueva comprobación de escala cero después de la suite de 40.
- Se verifican rango finito esperado, excepción original con NaN/Infinity, contexto de tiles ante escala cero, historial de 24 entradas, throttling de errores repetidos y cancelación del muestreo al destruir el propietario.
- Script PowerShell: parser sin errores; ejecución con adb simulado aprobada (get-state, reloj, PID, meminfo, filtrado de líneas privadas, conservación de diagnóstico/ANR y cierre al terminar logcat). Q/Ctrl+C y mensajes reales de fabricante pendientes de prueba interactiva en teléfono físico.
- `git diff --check`: correcto. `git apply --reverse --check diagnostics/tracked-changes.patch`: correcto.
- No se reprodujo el cierre, no se hizo perfilado de memoria real ni se instaló APK. Los resultados no identifican aún la causa del crecimiento de memoria.
- El build profile universal se detuvo tras 571 s esperando una descarga HTTPS de Gradle. La comprobación offline terminó con un error de resolución en `:app:checkProfileDuplicateClasses` (no un hallazgo de clases duplicadas): faltan los JAR `io.flutter:armeabi_v7a_profile` y `io.flutter:x86_64_profile`, versión `1.0.0-a10d8ac38de835021c8d2f920dbf50a920ccc030`. No se validó un APK universal.
- **APK profile ARM64 compilado correctamente** con Gradle offline (`assembleProfile`, salida 0), diagnóstico activado y commit definido. Ruta: `build/app/outputs/flutter-apk/app-profile.apk`, **35.893.680 bytes**, SHA-256 `CB86BC74416E35D13F269C99DF50B20EBE9CF3A2BC07A826C49B0D724554E8DD`. Se comprobó `lib/arm64-v8a/libapp.so` dentro del APK. No instalado ni probado en hardware.
- Compilación inicial mediante Flutter: JBR 21.0.10 de Android Studio. Comprobaciones Gradle offline: JDK Eclipse Adoptium **17.0.19**, Gradle **9.1.0**, Android Gradle Plugin **9.0.1**, compile SDK **37.0**, configuraciones existentes. Hubo advertencias de deprecaciones Kotlin/Java y compatibilidad de compile SDK; no se modificaron para esta instrumentación.

Los primeros intentos dentro del sandbox encontraron permisos de telemetría del SDK; las validaciones finales se ejecutaron con acceso autorizado al SDK local. No se alteraron versiones ni configuración del SDK.

Para reproducir el empaquetado offline ARM64 desde la raíz, con ese JDK disponible en JAVA_HOME y dependencias previamente resueltas:

```powershell
$diagnosticDefines = @(
  'BOND_MAP_DIAGNOSTICS=true',
  'BOND_FRONTEND_COMMIT=346adf6bf4f0cbc9d93d127c981eb646d35690b9'
) | ForEach-Object { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_)) }
$encodedDiagnosticDefines = $diagnosticDefines -join ','
Push-Location android
try {
  .\gradlew.bat --offline -q '-Ptarget-platform=android-arm64' '-Ptarget=lib/main.dart' "-Pdart-defines=$encodedDiagnosticDefines" assembleProfile
} finally {
  Pop-Location
}
```
