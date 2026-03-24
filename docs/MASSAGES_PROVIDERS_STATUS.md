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
- Se puede seleccionar un prestador.
- Se puede crear un prestador nuevo.
- Se puede editar el prestador seleccionado:
  - nombre
  - especialidad
  - contacto
- Se puede activar o desactivar un prestador.
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

## Dependencias con backend
- `GET /massages/providers` debe devolver proveedores con `therapists` embebidos.
- `POST /massages/bookings` y `PUT /massages/bookings/{id}` deben aceptar `therapistId`.
- `POST /massages/providers/{providerId}/therapists` debe crear masajista.
- `PUT /massages/providers/{providerId}/therapists/{therapistId}` debe actualizar masajista.

## Pendiente inmediato
- Validar el contrato exacto del backend real para asegurar nombres de campos y estructura JSON final.
