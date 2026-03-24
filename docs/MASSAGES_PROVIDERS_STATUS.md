# MASSAGES PROVIDERS STATUS

Fecha: 2026-03-24
Modulo: `Massagens`
Pantalla principal: `lib/features/massages/presentation/massage_booking_page.dart`

## Alcance implementado hasta ahora

### Modelo funcional
- El flujo operativo de atenciones ahora es `prestador -> masajista`.
- Un prestador puede tener varios masajistas.
- Cada masajista puede estar `activo` o `inactivo`.
- Las nuevas atenciones solo deben usar prestadores activos y masajistas activos.
- El historico mantiene proveedor y masajista aunque luego queden inactivos.

### Dominio y contrato frontend
- `MassageProvider` ahora incluye `therapists`.
- Se agrego la entidad `MassageTherapist`.
- `MassageBooking` ahora maneja `therapistId`, `therapistName` y `therapistActive`.
- `CreateMassageBookingModel` y `UpdateMassageBookingModel` envian `providerId` y `therapistId`.
- `MassageAppService` y `HttpMassageAppService` ahora incluyen:
  - `createTherapist`
  - `updateTherapist`

### UI de Prestadores
- Se puede listar prestadores.
- El dialogo abre sin prestador preseleccionado.
- Se muestra un resumen previo antes del listado y del panel de edicion.
- Se puede seleccionar un prestador.
- Se puede crear un prestador nuevo.
- Se puede editar el prestador seleccionado:
  - nombre
  - especialidad
  - contacto
- Se puede filtrar por nombre con coincidencia parcial de cadena.
- Si no hay coincidencias, la UI muestra estado vacio.
- Se puede activar o desactivar un prestador.
- La activacion ahora expone leyenda visible:
  - `ON` azul
  - `OFF` rojo
- Dentro del prestador seleccionado se puede:
  - listar masajistas
  - agregar masajistas
  - activar o desactivar masajistas

### UI de Atenciones
- El formulario de atencion primero selecciona prestador.
- Luego filtra y selecciona masajista del prestador elegido.
- La agenda y los listados muestran proveedor y masajista.
- La validacion de solapamiento ahora corre por `therapistId`.

### Ajustes de layout aplicados
- Se corrigio overflow del panel derecho del dialogo de prestadores.
- El bloque derecho ahora usa scroll interno y acciones fijas abajo.
- La lista de masajistas usa altura acotada para no romper el dialogo.
- Las tarjetas de prestadores fueron reducidas y compactadas.
- El flujo de gestion ahora separa estado neutro, estado de alta y estado de edicion.

## Dependencias con backend
- `GET /massages/providers` debe devolver proveedores con `therapists` embebidos.
- `POST /massages/bookings` y `PUT /massages/bookings/{id}` deben aceptar `therapistId`.
- `POST /massages/providers/{providerId}/therapists` debe crear masajista.
- `PUT /massages/providers/{providerId}/therapists/{therapistId}` debe actualizar masajista.

## Estado real de backend
- El backend no vive en este repo frontend.
- El backend operativo vive en [quadras](/c:/Users/Public/Documents/Proyectos/quadras).
- Para este alcance de `prestadores -> masajistas`, ya se implemento backend en `quadras` con:
  - entidad `MassageTherapist`
  - endpoints `POST/PUT /api/v1/massages/providers/{providerId}/therapists`
  - `therapistId` obligatorio en bookings
  - conflicto de horario validado por masajista
- Resultado: el pendiente principal ya no es implementacion de backend sino validacion punta a punta del contrato real entre ambos repos.

## Validacion realizada
- Se corrigio la migracion `V7` del backend para MySQL y se limpio el estado fallido de Flyway en entorno local.
- El backend de [quadras](/c:/Users/Public/Documents/Proyectos/quadras) ya arranca correctamente con el dominio `prestador -> masajista`.
- Se valido el flujo real punta a punta para:
  - listar prestadores con masajistas embebidos
  - agregar masajista dentro de un prestador
  - usar `providerId + therapistId` en el circuito de atenciones

## Pendiente imediato
- Ejecutar una nueva pasada de regresion sobre agenda y edicion de atenciones para cubrir casos con masajistas inactivos e historico existente.

## Regla de trabajo a partir de este punto
- Todo cambio funcional de `Massagens` que modifique contrato de datos debe trabajarse en paralelo en:
  - frontend `quedras-front`
  - backend `quadras`
- No se considera cerrado un cambio de `prestadores/masajistas` hasta validar:
  - request real al backend
  - response real del backend
  - prueba manual punta a punta
