# Enlaces de invitación

Bond reconoce enlaces HTTPS con el formato:

```text
https://bond.app/invite/ABCDEF
```

La aplicación conserva solamente el código normalizado como invitación
pendiente. El enlace completo no se guarda en el backend ni en la base de
datos.

## Android App Links

El `AndroidManifest.xml` ya declara el filtro HTTPS para `bond.app` con
`android:autoVerify="true"`. Para que Android verifique el dominio en una
instalación de producción, el servidor debe publicar:

```text
https://bond.app/.well-known/assetlinks.json
```

Contenido de referencia (los fingerprints deben provenir de los certificados
reales de firma; no deben inventarse):

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.bond_front",
      "sha256_cert_fingerprints": [
        "<SHA256_DEL_CERTIFICADO_DE_RELEASE_O_PLAY_APP_SIGNING>"
      ]
    }
  }
]
```

Si cambia el `applicationId` antes del despliegue, también debe actualizarse
`package_name`. Con el filtro local puede probarse la entrega del intent usando
`adb`; sin `assetlinks.json`, un toque normal puede abrir el navegador o mostrar
un selector según la versión y la configuración del dispositivo.

## iOS Universal Links

El target Runner ya incluye el entitlement `applinks:bond.app`. El dominio debe
publicar, sin redirecciones:

```text
https://bond.app/.well-known/apple-app-site-association
```

Contenido de referencia:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["<APPLE_TEAM_ID>.com.example.bondFront"],
        "components": [
          { "/": "/invite/*" }
        ]
      }
    ]
  }
}
```

El `APPLE_TEAM_ID` debe obtenerse de la cuenta real de Apple Developer. Si el
bundle identifier cambia, el `appID` externo también debe actualizarse.

## Aplicación no instalada

No se implementa deferred deep linking. Cuando Bond no está instalada, la URL
HTTPS queda a cargo de `bond.app`, que debe servir una landing/download page.
Esa página y los dos archivos de asociación anteriores pertenecen al despliegue
del dominio y no a este repositorio móvil.
