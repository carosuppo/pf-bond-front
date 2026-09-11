# Bond Frontend

## Proyecto

Aplicación móvil privada de Bond desarrollada con Flutter. El alcance actual contempla únicamente Android.

## Arquitectura

El código está organizado por features y cuenta con un núcleo compartido.

```text
lib/
├── core/
│   ├── config/
│   ├── network/
│   ├── preferences/
│   ├── routes/
│   ├── screens/
│   ├── storage/
│   ├── theme/
│   ├── validators/
│   └── widgets/
└── features/
    └── feature_name/
        ├── constants/
        ├── formatters/
        ├── mappers/
        ├── models/
        ├── providers/
        ├── screens/
        ├── services/
        ├── utils/
        └── widgets/
```

Las funcionalidades de ubicación agregan servicios nativos del dispositivo y comunicación WebSocket.

## Estado de la aplicación

El proyecto utiliza actualmente dos mecanismos de estado:

- `provider` y `ChangeNotifier` se utilizan principalmente en autenticación, grupos y perfil.
- Riverpod se utiliza en ubicación mediante `NotifierProvider`.

`main.dart` inicializa un `ProviderScope` y un `MultiProvider`. Mantener el mecanismo utilizado por cada feature y no migrar todo el proyecto sin una necesidad explícita.

## Reglas de implementación

- Mantener la organización por features.
- No colocar lógica de negocio, requests HTTP ni acceso a almacenamiento directamente en Screens o Widgets.
- No duplicar validators, clientes HTTP, componentes visuales ni transformaciones existentes.
- Utilizar los Models request y response existentes antes de crear modelos equivalentes.
- Utilizar `AppColors`, el Theme y los Widgets compartidos en lugar de hardcodear estilos.
- No introducir otra librería de estado, navegación o networking sin una necesidad concreta.
- No introducir `dynamic`, `Object` o tipos implícitos cuando el tipo pueda declararse explícitamente.
- No cambiar permisos, tracking en segundo plano, reconexión WebSocket o configuración Android sin revisar sus efectos.
- No agregar lógica de backend dentro del frontend ni modificar contratos sin revisar el consumidor correspondiente.

## Ejecución y validación

Desde `bond-front`:

```bash
flutter pub get
flutter run
```

Ejecutar las validaciones relacionadas con el cambio:

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Si el cambio afecta el contrato con el backend, la navegación, los permisos Android o la ubicación, validar también el flujo integrado correspondiente.
