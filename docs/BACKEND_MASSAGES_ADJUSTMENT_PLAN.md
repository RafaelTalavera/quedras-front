# BACKEND MASSAGES ADJUSTMENT PLAN

## Objetivo
- Alinear el backend de `Massagens` con el frontend ya preparado para edicion, cancelacion con observacion y auditoria por usuario.

## Cambios funcionales requeridos
1. Extender el modelo de `massage booking` con estado:
- `SCHEDULED`
- `CANCELLED`

2. Agregar soporte de edicion de atendimento:
- Endpoint esperado: `PUT /massages/bookings/{id}`
- Debe permitir actualizar fecha, hora, cliente, referencia, tratamiento, valor, prestador y datos de pago.

3. Agregar soporte de cancelacion sin borrado:
- Endpoint esperado: `PATCH /massages/bookings/{id}/cancel`
- Debe exigir `cancellationNotes`.
- Debe conservar el registro historico y cambiar el estado a `CANCELLED`.

## Auditoria requerida
- Persistir `createdAt`, `updatedAt`, `cancelledAt`.
- Persistir `createdBy`, `updatedBy`, `cancelledBy`.
- El usuario debe obtenerse del JWT autenticado en backend, no desde payload libre del cliente.

## Validaciones de negocio
- Un atendimento cancelado no debe poder editarse.
- Un atendimento cancelado no debe poder cancelarse nuevamente.
- Solo atendimientos con estado activo deben bloquear conflictos de horario.
- No deben existir endpoints `DELETE` para registros operativos de agenda.

## Contrato JSON esperado por frontend
- Campos minimos del booking:
  - `id`
  - `bookingDate`
  - `startTime`
  - `clientName`
  - `guestReference`
  - `treatment`
  - `amount`
  - `providerId`
  - `providerName`
  - `providerActive`
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

## Plan de implementacion backend
1. Migracion de base de datos para agregar columnas de estado, cancelacion y auditoria.
2. Actualizacion de entidad/modelo y DTOs de `massage booking`.
3. Actualizacion de servicio de aplicacion con reglas de negocio y auditoria.
4. Exposicion de endpoints `PUT` y `PATCH /cancel`.
5. Tests unitarios y de integracion para crear, editar y cancelar con trazabilidad de usuario.
6. Prueba manual con JWT real verificando persistencia de usuario en BD y logs.

## Criterio de cierre
- El backend responde contratos compatibles con el frontend actual.
- Crear, editar y cancelar dejan rastreo completo de usuario y timestamps.
- La cancelacion no elimina el registro ni rompe el historial de agenda.
