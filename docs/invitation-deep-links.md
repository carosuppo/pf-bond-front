# Enlaces de invitación

Las invitaciones usan una URL HTTP/HTTPS normal del backend como punto de
entrada y un esquema personalizado únicamente para abrir la aplicación:

```text
WhatsApp
  -> ${API_BASE_URL}/invite/ABCDEF
  -> GET /invite/ABCDEF
  -> redirección HTTP a bond://invite/ABCDEF
  -> Bond
```

`GET /invite/:code` es un endpoint público. Normaliza y valida el código, y
luego redirige a la aplicación. No consulta una sesión, no agrega miembros y no
modifica la base de datos. El ingreso al grupo ocurre exclusivamente desde Bond
mediante el `POST /group/join` autenticado.

La aplicación guarda solamente el código normalizado como invitación pendiente.
Si hay una sesión activa, procesa el join y abre el grupo. Si no hay sesión,
conserva la invitación durante login o registro y la procesa después de
autenticar. Si la persona ya pertenece al grupo, selecciona ese grupo y lo abre.

## Configuración móvil

Android registra un `intent-filter` para:

```text
bond://invite/...
```

Se usa un esquema personalizado sin `android:autoVerify`; por eso no se
necesitan archivos de asociación de dominio. iOS registra el mismo esquema
`bond` en `CFBundleURLTypes`.

## Desarrollo

`API_BASE_URL` debe apuntar a una dirección del backend que sea alcanzable desde
el celular. Por ejemplo:

```dotenv
API_BASE_URL=http://192.168.X.X:3000
```

La PC y el celular deben estar en una red donde esa dirección sea accesible. No
se debe usar `localhost` para un enlace enviado al teléfono: allí `localhost`
representa al propio teléfono.

Para probar directamente la apertura de la aplicación en Android:

```powershell
adb shell am start -a android.intent.action.VIEW -d "bond://invite/ABCDEF"
```

Para probar el recorrido completo con un único celular:

1. Iniciar el backend escuchando en la red local.
2. Configurar `API_BASE_URL` con la IP LAN de la PC y el puerto del backend.
3. Ejecutar Bond en el celular físico.
4. Iniciar sesión con la cuenta A y crear o abrir un grupo.
5. Tocar **Invitar por WhatsApp** y enviarse el mensaje a uno mismo.
6. Cerrar sesión en Bond.
7. Tocar en WhatsApp la URL HTTP recibida.
8. Verificar que el navegador llegue a `GET /invite/ABCDEF` y abra Bond con
   `bond://invite/ABCDEF`.
9. Iniciar sesión con la cuenta B.
10. Verificar que Bond se una automáticamente, seleccione el grupo invitado y
    abra el mapa.
11. Repetir la prueba con Bond completamente cerrada antes de tocar el enlace.

## Producción

`API_BASE_URL` debe ser la URL HTTPS pública del backend, por ejemplo:

```dotenv
API_BASE_URL=https://api.example.com
```

El mensaje compartido se adapta a ese valor sin cambios de código. No hace
falta desplegar una aplicación web completa: el endpoint público de invitación
es el puente hacia el esquema de la app.
