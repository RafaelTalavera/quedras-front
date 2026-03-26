# PLAN FRONT Y BACK TOURS / VIAGENS

## Objetivo
- Implementar `Tours e viagens` con el mismo criterio operativo y visual de `Massagens` y `Quadras`.
- Permitir registrar tours y viajes sin bloqueo por superposicion horaria.
- Mantener trazabilidad de proveedor, cobro, comision y pagos.
- Permitir que cada proveedor administre un catalogo de destinos, paseos o traslados reutilizable en el agendamiento.

## Reglas funcionales confirmadas
- El usuario puede lanzar agendamientos de:
  - `TOUR`
  - `TRAVEL`
- Tours y viajes pueden superponerse.
- Cada agendamiento debe tener:
  - `startAt`
  - `endAt`
  - `provider`
  - `providerOffering` opcional
  - `amount`
  - `commissionPercent`
  - `description`
  - estado de pago
  - forma de pago
- `amount` y `commissionPercent` deben ser editables en cada agendamiento.
- El operador puede seleccionar un item predefinido del proveedor y luego ajustar valor, descripcion o tipo si hace falta.
- La comision se calcula como porcentaje sobre el valor del servicio.
- Los resumenes deben priorizar:
  - cuanto se cobro
  - cuanto se recibio
  - cuanto de comision genero cada proveedor

## Estado actual del frontend
- Antes de este cambio la seccion `tours` era solo estatica.
- Ahora el frontend ya expone:
  - dominio `lib/features/tours/domain/tours_models.dart`
  - contrato `lib/features/tours/application/tours_app_service.dart`
  - cliente HTTP `lib/features/tours/infrastructure/http_tours_app_service.dart`
  - pantalla operativa `lib/features/tours/presentation/tours_travel_page.dart`
- La UI ya permite:
  - crear agendamiento
  - editar agendamiento
  - cancelar agendamiento
  - registrar pago
  - mantener proveedores
  - mantener destinos/servicios por proveedor
  - seleccionar destino/servicio del proveedor dentro del booking
  - ver agenda diaria
  - ver agenda mensual
  - ver resumen por proveedor

## Contrato minimo esperado del backend

### Proveedor
- `id`
- `name`
- `contact`
- `defaultCommissionPercent`
- `active`
- `updatedAt`
- `updatedBy`
- `offerings[]`

### Item del proveedor
- `id`
- `providerId`
- `serviceType`
- `name`
- `amount`
- `description`
- `active`
- `updatedAt`
- `updatedBy`

### Agendamiento
- `id`
- `serviceType`
- `startAt`
- `endAt`
- `clientName`
- `guestReference`
- `providerId`
- `providerName`
- `providerActive`
- `providerOfferingId`
- `providerOfferingName`
- `amount`
- `commissionPercent`
- `commissionAmount`
- `description`
- `paid`
- `paymentMethod`
- `paymentDate`
- `paymentNotes`
- `status`
- `cancellationNotes`
- `createdAt`
- `updatedAt`
- `cancelledAt`
- `createdBy`
- `updatedBy`
- `cancelledBy`

### Resumen por proveedor
- `providerId`
- `providerName`
- `providerActive`
- `scheduledCount`
- `cancelledCount`
- `paidCount`
- `pendingCount`
- `grossAmount`
- `paidAmount`
- `pendingAmount`
- `commissionAmount`
- `lastBookingAt`

## Endpoints esperados
- `GET /tours/providers`
- `POST /tours/providers`
- `PUT /tours/providers/{id}`
- `GET /tours/bookings`
- `POST /tours/bookings`
- `PUT /tours/bookings/{id}`
- `PATCH /tours/bookings/{id}/payment`
- `PATCH /tours/bookings/{id}/cancel`
- `GET /tours/reports/providers/summary?dateFrom=YYYY-MM-DD&dateTo=YYYY-MM-DD`

## Reglas de negocio backend
- No debe existir validacion de overlap para tours/viajes.
- El catalogo de cada proveedor debe viajar dentro del payload de proveedor para simplificar la operacion en front.
- Solo agendamientos `SCHEDULED` cuentan para cobro y resumen operativo.
- Un agendamiento cancelado:
  - no debe poder pagarse
  - no debe poder cancelarse de nuevo
  - no debe bloquear nuevas operaciones
- La comision debe recalcularse siempre a partir de:
  - `amount`
  - `commissionPercent`
- `createdBy`, `updatedBy` y `cancelledBy` deben salir del JWT del backend.

## Orden recomendado
1. Backend: entidad, migracion y DTOs.
2. Backend: endpoints CRUD operativo y resumen.
3. Backend: tests para crear, editar, pagar, cancelar y superponer.
4. Frontend: conectar sobre el backend real y validar contratos.
5. Validacion manual punta a punta con dos reservas superpuestas de distintos proveedores.

## Criterio de cierre
- El frontend actual consume el backend sin adaptadores temporales.
- El usuario puede registrar tours y viajes superpuestos.
- El resumen por proveedor informa cobrado, recibido y comision.
