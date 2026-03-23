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

4. Confirmar soporte de actualizacion rapida de pago:
- Endpoint esperado: `PATCH /massages/bookings/{id}/payment`
- Debe exigir `paymentMethod` y `paymentDate`.
- Debe persistir `paid = true`, `paymentMethod`, `paymentDate` y `paymentNotes`.
- Debe devolver el booking completo actualizado, no solo un `ack`.

## Auditoria requerida
- Persistir `createdAt`, `updatedAt`, `cancelledAt`.
- Persistir `createdBy`, `updatedBy`, `cancelledBy`.
- El usuario debe obtenerse del JWT autenticado en backend, no desde payload libre del cliente.
- Al registrar pago se debe actualizar al menos `updatedAt` y `updatedBy`.

## Validaciones de negocio
- Un atendimento cancelado no debe poder editarse.
- Un atendimento cancelado no debe poder cancelarse nuevamente.
- Un atendimento cancelado no debe poder pagarse.
- Debe existir un criterio explicito para reintentos de pago sobre bookings ya marcados como `paid`.
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
3. Actualizacion de servicio de aplicacion con reglas de negocio, auditoria y registro rapido de pago.
4. Exposicion de endpoints `PUT`, `PATCH /cancel` y `PATCH /payment`.
5. Tests unitarios y de integracion para crear, editar, cancelar y registrar pago con trazabilidad de usuario.
6. Prueba manual con JWT real verificando persistencia de usuario en BD, respuesta completa del booking y logs.

## Criterio de cierre
- El backend responde contratos compatibles con el frontend actual.
- Crear, editar, cancelar e informar pago dejan rastreo completo de usuario y timestamps.
- La cancelacion no elimina el registro ni rompe el historial de agenda.
