# PLAN FRONTEND - AGENDA Y ALERTAS DE MANTENIMIENTO

Fecha: 2026-10-28  
Estado: `En implementacion`
Tipo: `Cross-repo`

Documento canonico de dominio, contratos, persistencia, fases y criterios de
aceptacion:

`C:/Users/Public/Documents/Proyectos/quadras/docs/MAINTENANCE_ALERTS_AND_CALENDAR_PLAN.md`

## Alcance Flutter

- incorporar agenda diaria, semanal y mensual de mantenimiento;
- reutilizar `lib/core/widgets/operational_timeline.dart` y los estandares
  visuales existentes;
- separar backlog de ordenes sin agenda;
- agregar campana global, contador no leido e historial de avisos;
- abrir la orden desde aviso interno, SSE o push;
- presentar `Reagendar` y `Cerrar exitosamente` como acciones principales;
- exigir notas de resolucion al cerrar exitosamente;
- mantener `Iniciar trabajo` en el detalle normal de la orden;
- registrar y revocar suscripciones push sin exponer secretos;
- soportar estados de permiso, canal no disponible, offline y token invalido;
- excluir Google Calendar y cualquier OAuth de Google.

## Definiciones funcionales confirmadas

- destinatarios: responsable autenticado asignado y operadores o supervisores
  autorizados;
- zona horaria: `America/Sao_Paulo`;
- descartar oculta el aviso actual, pero no resuelve la orden;
- el aviso de inicio no se repite; al vencer el fin aparece un aviso de atraso y
  puede repetirse cada 60 minutos dentro de la jornada;
- las notas de cierre son obligatorias;
- Windows cerrado mediante WNS/MSIX no bloquea la primera salida; web/PWA y
  Windows con la aplicacion abierta son la prioridad.

## Orden de trabajo

1. Modelos y contratos aditivos (`scheduleVersion`, notificaciones y
   suscripciones).
2. Agenda por rango con vistas diaria, semanal y mensual.
3. Formulario de reagendamiento con motivo y control de version.
4. Campana global y dialogo de resolucion.
5. Actualizacion por SSE y ciclo de vida de la aplicacion.
6. Push web/PWA y deep link a la orden.
7. Adaptadores y validacion especifica de plataformas restantes.

## Restricciones

- el frontend no calcula autoritativamente vencimientos;
- el push no cambia estados directamente;
- no almacenar credenciales privadas de proveedores push;
- no ocultar la campana si el usuario rechaza permisos;
- no hacer polling por fila ni cargar historico completo para la agenda;
- no declarar soporte en segundo plano sin prueba en la plataforma real.

## Validacion minima por entrega

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Las pruebas focalizadas deben cubrir agenda, campana, reagendamiento, cierre,
concurrencia, permisos, deep links y recuperacion cuando el push no llega.

## Avance

### 2026-10-28 - Contrato base de reagendamiento

- agregado `scheduleVersion` al modelo de orden, compatible con respuestas que
  aun no incluyan el campo;
- agregado `RescheduleMaintenanceOrderModel`;
- agregado `rescheduleOrder` al puerto y al adaptador HTTP;
- cubiertos ruta, metodo, payload y deserializacion mediante prueba focalizada;
- pendiente integrar el formulario, el manejo visual de `409` y las vistas de
  agenda.

Validacion: `flutter analyze` sin errores (42 avisos informativos preexistentes)
y `flutter test` con 77 pruebas exitosas.

### 2026-10-28 - Consulta de agenda por intervalo

- agregado modelo `MaintenanceCalendar` con ordenes agendadas y backlog
  separados;
- agregado `getCalendar` con rango exclusivo, filtros y limite de backlog;
- cubierto el contrato HTTP y la deserializacion mediante prueba focalizada;
- pendiente consumirlo desde la pantalla y renderizar vistas semanal, diaria y
  mensual.

Validacion acumulada: `flutter analyze` sin errores (42 avisos informativos
preexistentes) y `flutter test` con 78 pruebas exitosas.

### 2026-10-28 - Agenda semanal integrada

- la pantalla consume el calendario por el intervalo de la semana seleccionada;
- agregado timeline semanal con navegacion, leyenda de estados y apertura del
  detalle de orden;
- las ordenes que cruzan medianoche se dividen visualmente por dia dentro del
  horario operativo `06:00-23:00`;
- agregado backlog separado, indicador de resultados adicionales y estados
  vacios;
- el arrastre queda deshabilitado hasta incorporar confirmacion de motivo,
  `scheduleVersion` y manejo de `409 Conflict`.

Validacion acumulada: `flutter analyze` sin errores (42 avisos informativos
preexistentes) y `flutter test` con 79 pruebas exitosas.

### 2026-10-28 - Reagendamiento confirmado y control de concurrencia

- agregado formulario `Agendar` / `Reagendar` con inicio, fin y motivo
  obligatorio;
- habilitado arrastre de bloques editables conservando la duracion y mostrando
  confirmacion antes de guardar;
- la solicitud envia el `scheduleVersion` observado;
- un `409 Conflict` recarga la agenda y presenta un aviso especifico, sin
  sobrescribir cambios de otro usuario;
- agregadas pruebas de widget para envio correcto y conflicto concurrente.

Validacion acumulada: `flutter analyze` sin errores (42 avisos informativos
preexistentes) y `flutter test` con 81 pruebas exitosas.

### 2026-10-28 - Modos diario, semanal y mensual con filtros

- agregados modos de agenda con rangos de consulta acordes al periodo activo;
- las vistas diaria y semanal usan la linea de tiempo y la mensual una lista
  cronologica compacta;
- navegacion temporal adaptada al modo seleccionado;
- filtros de ubicacion, prestador, estado y prioridad aplicados en servidor a
  agenda y backlog;
- agregadas pruebas de rangos y propagacion de filtros.

Validacion acumulada: `flutter analyze` sin errores (42 avisos informativos
preexistentes) y `flutter test` con 83 pruebas exitosas.

### 2026-10-28 - Dependencia backend preparada para avisos

- el backend ya dispone de zona operativa tipada, feature flags seguros y
  persistencia base para notificaciones y outbox;
- bandeja, detector, SSE y push siguen desactivados hasta completar sus
  contratos y comportamiento;
- no se requieren cambios Flutter en este incremento.

### 2026-10-28 - Detector backend preparado

- el backend ya detecta de forma idempotente el primer aviso `DUE` y
  `OVERDUE` dentro de la jornada operativa;
- la seleccion de destinatarios y la persistencia conjunta de notificacion y
  outbox estan implementadas y verificadas;
- el detector permanece desactivado por defecto y todavia no existe una API de
  bandeja consumible por Flutter;
- no se requieren cambios Flutter en este incremento.

### 2026-10-28 - Ciclo de vida backend preparado

- los avisos activos ya se resuelven automaticamente cuando la orden se
  reagenda, inicia, completa o cancela;
- los push pendientes asociados se abandonan antes de resolver el aviso para
  evitar entregas obsoletas;
- aun falta la API autenticada de bandeja, contador, lectura y descarte antes
  de integrar la campana en Flutter;
- no se requieren cambios Flutter en este incremento.

### 2026-10-28 - API backend de bandeja disponible

- disponible listado paginado mediante `GET /api/v1/notifications` con filtro
  opcional por estado;
- disponible contador mediante `GET /api/v1/notifications/unread-count`;
- disponibles acciones idempotentes `PATCH /{id}/read` y
  `PATCH /{id}/dismiss` bajo `/api/v1/notifications`;
- cada usuario solamente puede consultar y modificar sus propios avisos;
- el siguiente incremento Flutter puede integrar modelos, adaptador HTTP,
  campana global, bandeja y apertura del detalle de la orden.

### 2026-10-28 - Campana y bandeja Flutter integradas

- agregados modelos tipados para notificacion, tipo, estado y pagina de
  resultados;
- el adaptador HTTP consume listado, contador no leido, lectura y descarte;
- agregada campana global visible desde cualquier seccion, con contador y
  semantica accesible;
- la bandeja presenta estados de carga, vacio y error, permite reintentar,
  abrir un aviso o descartarlo;
- abrir un aviso no leido lo marca como leido y navega a mantenimiento;
- la pantalla cambia a agenda diaria usando `dueAt` como fecha de referencia,
  recarga los datos y abre el dialogo operativo de la orden relacionada;
- si la orden ya no esta disponible se informa sin dejar la interfaz en un
  estado inconsistente;
- el contador se actualiza al iniciar, al volver la aplicacion a primer plano y
  despues de cerrar la bandeja; la invalidacion inmediata por SSE sigue
  pendiente.

Validacion acumulada:

- `flutter analyze`: sin errores; conserva 42 avisos informativos preexistentes
  por APIs de Flutter deprecadas;
- `flutter test`: 85 pruebas exitosas;
- nuevas pruebas del contrato HTTP y del flujo visual contador, bandeja,
  lectura y apertura.

### 2026-10-28 - Invalidacion SSE de avisos

- la campana y una bandeja abierta escuchan el stream autenticado ya utilizado
  por la agenda;
- el evento `maintenance/notifications-changed` actualiza contador y contenido
  sin polling periodico;
- las suscripciones respetan el ciclo de vida y se cancelan al liberar los
  widgets;
- el backend emite solamente despues del commit y sin datos sensibles;
- la funcion requiere activar
  `COSTANORTE_MAINTENANCE_ALERTS_SSE_ENABLED=true` en el backend.

Validacion acumulada:

- `flutter analyze`: sin errores; conserva 42 avisos informativos
  preexistentes;
- `flutter test`: 85 pruebas exitosas, incluida la reaccion de la campana al
  evento SSE.

### 2026-10-28 - Recurrencia backend de avisos vencidos

- el backend puede generar un nuevo aviso `OVERDUE` por cada intervalo
  configurable, con 60 minutos como valor por defecto;
- cada recurrencia llega como un registro independiente mediante el contrato
  existente de bandeja y dispara la invalidacion SSE ya soportada;
- no se requieren cambios en modelos, adaptador HTTP ni widgets Flutter;
- el ciclo de vida existente resuelve los avisos activos cuando la orden se
  reagenda, inicia, completa o cancela.

Validacion de este incremento:

- no se modifico codigo Flutter; se conserva la linea base de 85 pruebas y el
  analisis previo sin errores;
- backend validado con 144 pruebas exitosas y 38 migraciones Flyway.

### 2026-10-28 - Despachador backend de outbox preparado

- el backend ya reclama, entrega, reintenta y abandona trabajos push mediante
  un puerto desacoplado del proveedor;
- la concurrencia entre instancias se controla con reclamacion atomica y los
  trabajos interrumpidos se recuperan por timeout;
- aun no existe adaptador FCM ni registro de instalaciones, por lo que no debe
  activarse push en Flutter;
- no se modifico codigo Flutter en este incremento.

Validacion de este incremento:

- backend validado con 147 pruebas exitosas y 39 migraciones Flyway;
- se conserva la linea base Flutter de 85 pruebas y analisis sin errores.

### 2026-10-28 - API backend de suscripciones push disponible

- disponible `POST /api/v1/push/subscriptions` con el contrato:
  `installationId`, `platform`, `provider` y `token`;
- `platform` admite `WEB`, `ANDROID` e `IOS`; `provider` admite inicialmente
  `FIREBASE`;
- disponibles heartbeat y baja mediante
  `PATCH /api/v1/push/subscriptions/{installationId}/heartbeat` y
  `DELETE /api/v1/push/subscriptions/{installationId}`;
- el alta es idempotente y admite rotacion del token; la baja tambien es
  idempotente para una instalacion previamente registrada;
- el backend nunca devuelve el token y reasigna de forma segura dispositivos
  compartidos entre usuarios;
- todavia falta obtener permisos/token FCM, generar un `installationId`
  persistente e integrar alta, heartbeat, cierre de sesion y renovacion en
  Flutter web/PWA;
- no se modifico codigo Flutter en este incremento.

Validacion de este incremento:

- backend validado con 151 pruebas exitosas y 40 migraciones Flyway;
- se conserva la linea base Flutter de 85 pruebas y analisis sin errores.

### 2026-10-28 - Adaptador FCM backend disponible

- el backend ya entrega mediante Firebase HTTP v1 usando las suscripciones
  activas del usuario;
- tokens rechazados por Firebase se desactivan y los fallos transitorios usan
  los reintentos del outbox;
- el payload remoto no contiene datos sensibles y permite abrir la orden por
  `orderId`;
- Flutter aun debe incorporar Firebase Core/Messaging, configuracion web,
  permisos, token, renovacion, `installationId`, heartbeat y baja;
- no se modifico codigo Flutter en este incremento.

Validacion de este incremento:

- backend validado con 156 pruebas exitosas;
- la entrega contra Firebase real queda pendiente de credenciales y
  configuracion cliente del entorno de pruebas.

### 2026-10-28 - Firebase Messaging web/PWA integrado

- agregados `firebase_core` y `firebase_messaging` sin actualizar el resto de
  dependencias directas;
- Firebase esta desactivado por defecto y se inicializa solamente con
  `FIREBASE_ENABLED=true` y configuracion completa por `--dart-define`;
- el cliente registra el Firebase Installation ID al iniciar sesion, envia
  heartbeat al reanudar y elimina la suscripcion al cerrar sesion;
- el contador se invalida con mensajes en primer plano;
- tocar un push abre la orden de mantenimiento correspondiente, incluso desde
  inicio en frio;
- agregado `web/firebase-messaging-sw.js` para recepcion en segundo plano;
- agregado `scripts/run_web_with_firebase.ps1` para validar variables y lanzar
  Chrome sin guardar configuracion en el repositorio;
- el repositorio actual no contiene carpetas Android/iOS, por lo que esta
  entrega activa push remoto para web/PWA y mantiene Windows sobre SSE/campana.

Variables web requeridas:

- `FIREBASE_API_KEY`;
- `FIREBASE_PROJECT_ID`;
- `FIREBASE_MESSAGING_SENDER_ID`;
- `FIREBASE_WEB_APP_ID`;
- `FIREBASE_WEB_VAPID_KEY`;
- opcionales: `FIREBASE_AUTH_DOMAIN` y `FIREBASE_STORAGE_BUCKET`.

Validacion ejecutada:

- `flutter analyze`: sin errores, con 42 avisos informativos preexistentes;
- `flutter test`: 88 pruebas exitosas.

Pendiente de configuracion externa:

- completar variables, cuenta de servicio backend y permisos Firebase;
- verificar entrega real en primer plano, segundo plano y aplicacion cerrada.

### 2026-10-28 - Correccion del lanzador Firebase local

- `scripts/run_web_with_firebase.ps1` ahora pasa tambien
  `COSTANORTE_API_BASE_URL` a Flutter;
- usa `http://127.0.0.1:8080/api/v1` por defecto para evitar que una prueba
  local de Firebase consuma accidentalmente el backend productivo;
- permite sobreescribir el destino definiendo `COSTANORTE_API_BASE_URL` antes
  de ejecutar el script;
- detector y bandeja fueron comprobados contra el backend local; queda
  pendiente confirmar visualmente el push en Chrome con la instalacion
  Firebase registrada.

### 2026-10-28 - Consistencia entre backlog y mapa operacional

- comprobado contra la API local que las ordenes `229` y `232` de `Quarto
  104`, y las ordenes abiertas de `Areas comuns piso 1`, estaban presentes en
  los contratos backend;
- la divergencia provenia del frontend: el backlog usaba el calendario y el
  mapa dependia exclusivamente del informe ejecutivo de la fecha seleccionada;
- el mapa ahora forma una union por ID entre informe ejecutivo, agenda y
  backlog, conserva solo estados abiertos y evita duplicados;
- agregada regresion donde el informe ejecutivo esta vacio y el backlog aporta
  dos ordenes para la misma ubicacion; el mapa muestra `2 abertas`;
- `flutter test`: 89 pruebas exitosas;
- `flutter analyze`: sin errores nuevos y con los 42 avisos informativos
  preexistentes.

### 2026-10-29 - Dialogo operativo automatico de avisos

- completado el comportamiento original de `DUE_TO_START` y `OVERDUE`: un
  aviso nuevo recibido por SSE o Firebase en primer plano abre la orden sin
  requerir que el usuario pulse primero la campana;
- al iniciar la aplicacion se toma una linea base de notificaciones existentes,
  por lo que los avisos historicos no se abren en cascada;
- `DUE_TO_START` muestra `Hora de iniciar a ordem` y permite iniciar, editar o
  reagendar mediante las acciones existentes;
- `OVERDUE` muestra `Horario previsto encerrado` y orienta a concluir o
  reagendar si se necesita mas tiempo;
- `Concluir` queda habilitado para una orden `SCHEDULED` solamente cuando su
  hora final ya fue alcanzada; continua habilitado normalmente para
  `IN_PROGRESS`;
- el aviso se marca leido antes de abrir la accion para evitar reaperturas por
  el mismo evento, sin impedir la operacion si falla esa marca;
- agregadas pruebas para apertura automatica de un aviso nuevo y para las
  acciones de cierre/reagenda al vencer;
- `flutter test`: 91 pruebas exitosas;
- `flutter analyze --no-fatal-infos`: sin errores, con los mismos 42 avisos
  informativos preexistentes.
