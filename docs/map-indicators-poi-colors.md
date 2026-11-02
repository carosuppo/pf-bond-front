# Indicadores interactivos y colores de puntos de interés

Implementación en `feature/point-of-interest`, sobre el código actual de ambos repositorios.

## Indicadores fuera de pantalla

- Se quitó el IgnorePointer de la capa y se agregó un GestureDetector por indicador de 36 × 36. El Stack no tiene un detector ni fondo opaco que capture toda la pantalla.
- El callback `ValueChanged<LatLng> onLocationTap` comunica el punto a LocationMap, que ejecuta `_mapController.move(point, _mapController.camera.zoom)`.
- Aplica a otros miembros, miembros stale y “Vos”. Conserva zoom, rotación, color, dirección y la lógica existente de visibilidad/frescura.
- Los POI no generan indicadores offscreen.
- El tap del mapa que colapsa el panel expandido ahora se procesa mediante MapOptions.onTap: ya no hay una capa por encima que bloquee el indicador. Tocar un indicador no colapsa ni abre paneles.
- Las pruebas usan el FlutterMap y MapController reales, verifican coordenadas, zoom, rotación, color/flecha y que un tap/drag fuera del indicador llegue al mapa.

## Color persistente y banderas

Prisma incorpora `PointOfInterestColor` con exactamente RED, GREEN, ORANGE, BLUE, PURPLE, GREY y BLACK. `PointOfInterest.color` es obligatorio en persistencia y tiene default BLUE.

Migración: `Back/pf-bond-back/prisma/migrations/20260908010000_add_point_of_interest_color/migration.sql`. Agrega el enum y una columna NOT NULL DEFAULT BLUE, sin borrar datos. Los POI existentes quedan BLUE cuando se aplica. La migración fue creada, no aplicada a la base existente.

El flujo DTO → mapper → repository → response incluye color:

- POST sin color usa BLUE por compatibilidad.
- POST con color válido lo persiste.
- PATCH admite sólo `{"color":"PURPLE"}`.
- POST, GET de lista y PATCH devuelven color.
- `IsEnum` valida los siete valores; PINK, hexadecimales, números y null se rechazan con HTTP 400. Omitir color sigue permitido.

En Flutter, `PointOfInterestColor` centraliza todo el mapping:

| Backend | Enum Flutter | Color | Etiqueta |
|---|---|---|---|
| RED | red | Colors.red | Rojo |
| GREEN | green | Colors.green | Verde |
| ORANGE | orange | Colors.orange | Naranja |
| BLUE | blue | Colors.blue | Azul |
| PURPLE | purple | Colors.purple | Púrpura |
| GREY | grey | Colors.grey | Gris |
| BLACK | black | Colors.black | Negro |

El modelo usa BLUE sólo si falta el campo; un valor recibido fuera de contrato produce FormatException. CreateRequest envía el color seleccionado y UpdateRequest sólo envía color si se proporciona.

El editor usa siete ChoiceChip en Wrap, con círculos de color, etiqueta y selección con check. Siempre conserva una selección: BLUE al crear y el color guardado al editar. El color participa de `_dirty` y se incluye al guardar.

MapScreen conserva `_draftColor`, lo inicializa/restablece y recibe `onColorChanged` del editor. LocationMap recibe `previewColor`, por lo que el cambio se ve sin guardar. Tanto el preview como los POI persistidos usan:

- bandera `Icons.flag_rounded`;
- borde del color seleccionado;
- relleno del mismo color con alpha 45 (55 en preview);
- nombre debajo con el estilo de texto existente.

La lista horizontal usa la misma bandera y color. Los miembros siguen usando Icons.location_pin con su comportamiento previo, mediante un builder separado.

## Presencia, WebSocket y notificaciones

- El color no forma parte de geometryChanged. Un cambio sólo de color no actualiza Location, no borra PointOfInterestPresence y no emite ingreso/egreso.
- Los resets por radio/latitud/longitud siguen iguales.
- No se cambió el protocolo WebSocket: PointOfInterestCreated/Updated siguen disparando GET y el modelo obtiene color de esa respuesta.
- La prueba integrada simula el GET posterior al evento de otro cliente y verifica que mapa/lista reciban el color nuevo.
- FCM, eventos de creación/modificación, foreground tracking y heartbeat no se modificaron.
- La prueba de pantalla completa detectó dos errores previos de desmontaje: setState desde dispose en GroupSelectorButton y ref.read desde dispose en MapScreen. Se corrigieron de forma puntual, sin cambiar el comportamiento del tracking. También se agregaron las llaves requeridas por el lint en un if del provider de preferencias, sin cambio funcional.

## Archivos

Backend, modificados:

- prisma/schema.prisma
- src/point-of-interest/dto/create-point-of-interest.dto.ts
- src/point-of-interest/dto/update-point-of-interest.dto.ts
- src/point-of-interest/dto/point-of-interest-response.dto.ts
- src/point-of-interest/interface/create-point-of-interest-data.interface.ts
- src/point-of-interest/interface/update-point-of-interest-data.interface.ts
- src/point-of-interest/mapper/point-of-interest.mapper.ts
- src/point-of-interest/repository/point-of-interest.prisma.repository.ts
- src/point-of-interest/point-of-interest.service.spec.ts
- src/point-of-interest/dto/point-of-interest.dto.spec.ts
- src/point-of-interest/presence/presence-reset.repository.spec.ts

Backend, nuevo:

- prisma/migrations/20260908010000_add_point_of_interest_color/migration.sql

Frontend, modificados:

- lib/features/location/widgets/location_map.dart
- lib/features/location/screens/map_screen.dart
- lib/features/point_of_interest/models/point_of_interest.dart
- lib/features/point_of_interest/models/point_of_interest_request.dart
- lib/features/point_of_interest/widgets/point_of_interest_editor.dart
- lib/features/group/widgets/group_selector_button.dart
- lib/features/notification/providers/notification_preferences_provider.dart

Frontend, nuevos:

- lib/features/point_of_interest/models/point_of_interest_color.dart
- test/features/location/offscreen_and_poi_map_test.dart
- test/features/point_of_interest/point_of_interest_color_test.dart
- test/features/point_of_interest/map_screen_color_test.dart
- docs/map-indicators-poi-colors.md

## Resultados de validación

- `npx prisma generate`: OK.
- `npm run build`: OK.
- `npm run lint`: OK.
- `npm test -- --runInBand`: 23 suites y 126 tests aprobados (14 casos agregados).
- `dart format lib test`: OK; verificación final de 109 archivos sin cambios pendientes de formato.
- `flutter analyze`: sin observaciones.
- `flutter test`: 72 tests aprobados (18 nuevos).
- `flutter build apk --debug`: OK. Artefacto: `build/app/outputs/flutter-apk/app-debug.apk`.
- El build conserva la advertencia de compatibilidad futura de firebase_core con Kotlin Gradle Plugin; no impide compilar y no se cambiaron dependencias.
- `git diff --check`: sin errores en ambos repositorios.

Los tests nuevos cubren los siete colores, fallback/valores inválidos, requests, defaults/edición/dirty/preview, indicadores propios/ajenos/stale, zoom/rotación/gestos, banderas/círculos/lista y reload por WebSocket. Las pruebas backend cubren creación/default, respuestas, PATCH sólo color, validación 400 y conservación de geometría/presencia/eventos.

## Prueba manual

### Preparación

En el backend, aplicar la migración cuando corresponda:

```powershell
npx.cmd prisma migrate deploy
npx.cmd prisma generate
npm.cmd run build
npm.cmd run start:dev
```

No usar migrate reset. Instalar el APK actualizado o ejecutar Flutter. Las cuentas A y B deben pertenecer al mismo grupo y usar el backend actualizado.

### A. Indicadores

1. Tener un miembro visible con ubicación vigente y desplazar el mapa hasta dejarlo fuera de pantalla.
2. Confirmar círculo del color del miembro con flecha hacia su ubicación.
3. Cambiar el zoom y tocar el círculo.
4. Confirmar que el mapa centra al miembro y conserva el zoom. Repetir con el mapa rotado.
5. Repetir para “Vos” y un miembro stale que todavía sea visible.
6. Arrastrar y hacer zoom lejos de los círculos: los gestos deben funcionar.
7. Expandir el panel del grupo y tocar un indicador: debe centrar sin modificar el panel.

### B. Crear

1. Abrir Agregar punto de interés; confirmar siete colores y Azul seleccionado.
2. Elegir una ubicación y Rojo.
3. Confirmar bandera, borde y relleno semitransparente rojos en el preview.
4. Completar nombre/radio y registrar.
5. Confirmar bandera roja en mapa y lista horizontal, con radio rojo transparente.
6. Cerrar y volver a abrir el mapa: el color debe persistir.

### C. Editar

1. Abrir información del POI rojo y tocar Editar.
2. Confirmar Rojo seleccionado.
3. Cambiar sólo a Púrpura: el preview debe cambiar inmediatamente.
4. Cancelar: debe solicitar descartar cambios.
5. Volver a editar, elegir Púrpura y guardar.
6. Confirmar mapa/lista púrpuras y ubicación/radio idénticos.

### D. Otro usuario

1. Mantener B en el mismo grupo mientras A cambia el color.
2. Confirmar que el evento WebSocket provoca el GET existente y B ve el color nuevo en mapa/lista.
3. Repetir creando un POI con otro color.
4. Si las notificaciones de creación/modificación están habilitadas, deben seguir llegando con sus textos habituales.

### E. POI existentes y contrato

1. Tras aplicar la migración, verificar un POI creado anteriormente: debe ser BLUE y editable.
2. POST /group/:groupId/point-of-interest sin color: respuesta color BLUE.
3. PATCH /group/:groupId/point-of-interest/:pointId con `{"color":"PURPLE"}`: respuesta PURPLE, sin modificar geometría.
4. PATCH con `{"color":"PINK"}`: HTTP 400.
5. GET del grupo: cada POI debe incluir su color.
6. Si hay baseline de presencia, guardar sólo color y volver a publicar la misma ubicación: sin ENTERED/EXITED. Las notificaciones de modificación del POI son independientes y pueden llegar.

Las pruebas manuales en dispositivos y la aplicación de la migración quedan para el entorno conectado; no se afirma haberlas ejecutado. No se hicieron commits, push, PR ni reset de base.
