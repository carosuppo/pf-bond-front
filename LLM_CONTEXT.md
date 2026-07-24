1. Proyecto

Este proyecto es el frontend móvil privado de Bond, una aplicación diseñada para mejorar la comunicación y coordinación entre grupos como familias, amigos y equipos de trabajo. Consume exclusivamente la API oficial del backend y está orientado a dispositivos móviles.

Actualmente incluye funcionalidades de geolocalización, gestión de eventos compartidos (viajes, salidas, reuniones, etc.) y gestión de recordatorios compartidos. En el futuro podrán incorporarse nuevas funcionalidades respetando la arquitectura existente.

El sistema operativo IOS no se tomará en cuenta a la hora de desarrollar, sólo se trabajará con Android.

2. Objetivo

El objetivo es mantener una base de código consistente, mantenible y escalable. Ante varias soluciones válidas, se debe priorizar la que mejor respete la separación de responsabilidades y los patrones existentes, evitando sugerir nuevas abstracciones, librerías o refactorizaciones que no hayan sido solicitadas.

3. Cómo interpretar el contexto

Al no tener acceso directo al repositorio, basá tus respuestas únicamente en este documento y en el código provisto en el chat, si es que hay uno.

Si una tarea requiere conocer un archivo no compartido (por ejemplo una Screen, un Widget, un Provider, un Service, un Model, una ruta o el Theme), solicitálo explícitamente en lugar de asumir su implementación o comportamiento.

4. Arquitectura

El proyecto está desarrollado con Flutter y utiliza una arquitectura organizada por Features.

Estructura general:

features/
├──feature_name/
│ ├──models/
│ ├──screens/
│ ├──services/
│ ├──widgets/

Flujo habitual de una interacción:

Usuario
↓
Screen
↓
Widget
↓
Provider (Riverpod)
↓
Service
↓
Backend (REST / WebSocket)

5. Convenciones del proyecto

Responsabilidades: Las Screens coordinan la interfaz de usuario. Los Widgets representan componentes reutilizables. Los Providers administran el estado de la aplicación. Los Services encapsulan toda comunicación con el backend o servicios externos. Los Models representan los datos utilizados por la aplicación.

Comunicación: Toda interacción con el backend debe realizarse mediante los Services. Utilizar HTTP para operaciones REST y WebSockets para funcionalidades en tiempo real.

Nomenclatura:

Archivos: snake*case (group_card.dart, event_details_screen.dart)
Clases: PascalCase (GroupCard)
Variables y métodos: camelCase
Widgets privados: prefijo * (\_GroupHeader)

6. Estado de la aplicación

El estado de la aplicación se administra mediante Riverpod.

Mantener el estado fuera de la interfaz. Evitar lógica de negocio dentro de Screens o Widgets.

7. Modelos

Los datos intercambiados con el backend deben representarse mediante Models.

Cuando una operación requiera transformar respuestas HTTP, utilizar DTOs separados del Model de la aplicación.

Evitar dynamic, Object o tipos implícitos cuando el tipo pueda declararse explícitamente.

8. Diseño

La interfaz utiliza Material Design 3.

Centralizar colores, tipografías y estilos mediante el Theme de la aplicación. Evitar valores hardcodeados dentro de los Widgets.

Priorizar interfaces simples, consistentes y optimizadas para dispositivos móviles

9. Dependencias

Antes de sugerir una nueva dependencia, priorizar las herramientas ya utilizadas por el proyecto.

Las librerías principales previstas son:

Flutter
Riverpod
flutter_map
geolocator
web_socket_channel
http

No proponer nuevas librerías salvo que la tarea lo requiera explícitamente.

10. Al enviar tus respuestas

Limitate estrictamente al alcance de la tarea solicitada. No realices refactorizaciones ajenas al objetivo.

No introduzcas nuevas librerías, patrones o abstracciones sin consultarlo previamente.

Justificá tus decisiones de diseño de forma breve únicamente cuando la solución elegida no sea la más evidente.

11. Información que puede ser necesaria

Dependiendo de la tarea, solicitá los siguientes archivos antes de implementar o asumir una solución si no están en el contexto:

Screen involucrada.
Widget involucrado.
Provider correspondiente.
Service correspondiente.
Models o DTOs asociados.
Configuración de rutas.
Theme de la aplicación.
