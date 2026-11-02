# Documentación familiar (Android)

Se accede desde el icono de carpeta de la barra inferior → **Documentación**. El selector superior usa el grupo activo compartido con las otras pestañas. Cambiar de grupo reinicia la carpeta, el filtro y el historial; se usan `ChangeNotifier`, el `ApiClient` y el tema existentes. Se retiró el acceso del menú de información del grupo.

El botón Atrás de Android cierra primero el selector si está abierto; después vuelve por las carpetas visitadas. Cuando se agota ese historial, vuelve a la pestaña anterior (o a la pantalla anterior si se abrió como ruta independiente). La pestaña de documentos no intercepta Atrás mientras está inactiva.

Las pruebas de navegación cubren el retorno por carpetas y rutas, el cambio de grupo con reinicio del historial, el cierre prioritario del selector y la pestaña inactiva. Tras este ajuste pasaron las 169 pruebas de Flutter, incluidas las 13 del módulo de documentación.

- Navegación raíz/carpetas/subcarpetas con regreso al padre y a raíz.
- Carga con nombre y archivo obligatorios; integrante y carpeta opcionales. PDF/JPEG/PNG/WebP, hasta 10 MiB. «Sin integrante» permite crear documentos generales del grupo o quitar una asociación al editar. El listado identifica estos documentos como «Sin integrante».
- Filtro por integrante en todas las subcarpetas, con ubicación visible. Los integrantes históricos se incluyen en el filtro y solo se mantienen en documentos existentes.
- Edición, cambio de integrante, movimiento y reemplazo opcional conservando el identificador.
- Renombrado de carpetas y confirmación explícita antes de borrar documentos o árboles completos. Cancelar no envía requests.
- Estados de carga, error, carpeta vacía y filtro sin resultados.

El selector Android usa Storage Access Framework: no se agregaron permisos ni dependencias. `DocumentChannel` lee un máximo de 10.485.760 bytes. Los PDF usan `PdfRenderer` del sistema, página por página. No se abren en aplicaciones externas ni se pasan tokens a visores de terceros.

Cada apertura/página descarga a través del endpoint autenticado del backend. Las imágenes y páginas renderizadas se mantienen en memoria; el visor purga su imagen al cerrar o pasar a segundo plano y vuelve a comprobar acceso al reanudar y cada 30 segundos mientras está visible. La revocación impide inmediatamente cualquier nueva descarga del backend; una imagen que ya se está viendo puede permanecer hasta la siguiente comprobación. No se puede revocar una captura o copia que un usuario ya haya obtenido.

Para PDF, Android requiere un descriptor seekable: se crea un archivo privado de caché y se desvincula inmediatamente después de abrirlo, antes de renderizar; también se elimina en `finally`. Al iniciar el canal se limpian restos de una interrupción del proceso. No hay caché persistente intencionada de documentos ni URLs de Storage.

Contrato: `/group/:groupId/documentation`, multipart de creación/edición, JSON de carpetas y bytes autenticados de contenido. Ver `docs/family-documentation.md` del backend para endpoints, migración, bucket privado, limpieza interna y pasos manuales.

Pruebas específicas: `flutter test test/features/documentation`. Cubren navegación, confirmación/cancelación recursiva, filtro y ubicación, errores de acceso, campos obligatorios, multipart de reemplazo, cancelación del selector y límites, PDF/imágenes con canal simulado y conservación del listado tras fallo de borrado. El APK debug compila. Falta validar la interacción real en un dispositivo Android con backend y bucket privado de prueba; no se contactaron servicios remotos. Los backups fueron excluidos por pedido del usuario.
