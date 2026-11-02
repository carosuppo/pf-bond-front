# Configuración de compilación

El archivo `.env` local no forma parte de los assets de Flutter. `tool/flutter_with_env.dart` lee únicamente `API_BASE_URL` y `CARTO_API_KEY` y las pasa al compilador como definiciones de compilación. No agregues credenciales de servidor al `.env` del frontend.

Para ejecutar Flutter usando el `.env` local:

```bash
dart run tool/flutter_with_env.dart run
```

Para compilar el AAB de producción:

```bash
dart run tool/flutter_with_env.dart build appbundle --release
```

El build de producción requiere `API_BASE_URL=https://srv2008002.hstgr.cloud` y una `CARTO_API_KEY` no vacía. Gradle verifica las definiciones recibidas; un build release ejecutado directamente sin esos valores también falla.

En modo debug, `API_BASE_URL` puede ser una URL HTTP o HTTPS válida. Si no se proporciona, se usa `http://10.0.2.2:3000` para el emulador Android local.
