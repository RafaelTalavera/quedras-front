# MASSAGES SUMMARY REPORT PLAN

Fecha: 2026-03-24
Modulo: `Massagens`
Frontend base: `lib/features/massages/presentation/massage_booking_page.dart`
Backend operativo relacionado: `C:/Users/Public/Documents/Proyectos/quadras`
Estado: `Implementado y visible en el sistema`

## Objetivo funcional
- Agregar en `Massagens` una seccion de resumen que devuelva una tabla por prestador.
- Cada fila debe mostrar resumen de `atenciones` y `cobros` del periodo consultado.
- Desde esa tabla, el operador debe poder seleccionar un prestador y ver el detalle operativo.

## Estado implementado en el sistema
- La pantalla de `Massagens` ya muestra el bloque `Resumo por prestador`.
- La visualizacion ya forma parte del flujo visible del sistema, sin remover:
  - `Resumo do mes`
  - agenda mensual
  - panel `Dia selecionado`
- El operador ya puede:
  - definir rango `inicio / fim`
  - consultar la tabla por prestador
  - seleccionar una fila
  - ver el detalle del prestador seleccionado
- El frontend ya consume los endpoints reales de reporte:
  - `GET /api/v1/massages/reports/providers/summary`
  - `GET /api/v1/massages/reports/providers/{providerId}/details`
- La actualizacion del reporte ya ocurre despues de:
  - crear atendimento
  - editar atendimento
  - cancelar atendimento
  - informar pago

## Estado previo analizado

### Frontend hoy
- El resumen actual de `Massagens` solo muestra metricas generales del mes:
  - volumen activo
  - prestadores y masajistas activos
  - ingreso previsto total
- La UI actual no tiene:
  - tabla agregada por prestador
  - selector de fila con detalle por prestador
  - filtros de periodo orientados a reporte
- El frontend solo consume:
  - `GET /massages/providers`
  - `GET /massages/bookings`
  - CRUD operativo de bookings, pago y cancelacion

### Backend hoy
- El backend real ya expone bookings con:
  - `providerId`
  - `providerName`
  - `therapistId`
  - `therapistName`
  - `amount`
  - `paid`
  - `paymentMethod`
  - `paymentDate`
  - `status`
- El backend no expone hoy:
  - endpoint agregado de resumen por prestador
  - endpoint de detalle de resumen por prestador
  - filtros por rango (`dateFrom/dateTo`) en bookings
  - paginacion o contrato de reporte

## Gap funcional exacto
- Hoy la pantalla puede calcular un resumen global del mes a partir de `_bookings`.
- Eso no alcanza para el requerimiento nuevo porque el operador necesita:
  - consolidado por prestador
  - navegacion hacia detalle
  - reglas de conteo y cobro consistentes con backend
- Si el frontend agregara todo localmente sobre `listBookings()` actual:
  - dependeria de traer demasiados registros
  - no tendria rango de fechas real
  - mezclaria logica de reporte y logica operativa en la UI
  - duplicaria reglas financieras y de cancelacion

## Decision recomendada
- Implementar un contrato de reporte dedicado en backend.
- Mantener el frontend operativo actual y agregar una capa de reporte separada dentro de `Massagens`.
- Reusar `bookings` existentes para el detalle cuando sea viable, pero no para el resumen agregado principal.

## Contrato backend recomendado

### 1. Resumen por prestador
Endpoint propuesto:
- `GET /api/v1/massages/reports/providers/summary?dateFrom=YYYY-MM-DD&dateTo=YYYY-MM-DD`

Respuesta propuesta:
```json
[
  {
    "providerId": 12,
    "providerName": "Spa Serena",
    "providerActive": true,
    "therapistsCount": 3,
    "scheduledCount": 18,
    "cancelledCount": 2,
    "attendedCount": 18,
    "paidCount": 11,
    "pendingCount": 7,
    "grossAmount": 2250.00,
    "paidAmount": 1380.00,
    "pendingAmount": 870.00,
    "lastBookingAt": "2026-03-24T16:00:00Z"
  }
]
```

Notas de negocio:
- `scheduledCount`: bookings con `status = SCHEDULED` dentro del rango.
- `cancelledCount`: bookings con `status = CANCELLED` dentro del rango.
- `attendedCount`: para esta fase puede ser equivalente a `scheduledCount`, porque el dominio actual no tiene estado separado `ATTENDED`.
- `paidCount`: cantidad de bookings `paid = true` y `status = SCHEDULED`.
- `pendingCount`: cantidad de bookings `paid = false` y `status = SCHEDULED`.
- `grossAmount`: suma de `amount` sobre bookings `SCHEDULED`.
- `paidAmount`: suma de `amount` sobre bookings `SCHEDULED` y `paid = true`.
- `pendingAmount`: suma de `amount` sobre bookings `SCHEDULED` y `paid = false`.

### 2. Detalle por prestador
Endpoint propuesto:
- `GET /api/v1/massages/reports/providers/{providerId}/details?dateFrom=YYYY-MM-DD&dateTo=YYYY-MM-DD`

Respuesta propuesta:
```json
{
  "providerId": 12,
  "providerName": "Spa Serena",
  "providerActive": true,
  "summary": {
    "scheduledCount": 18,
    "cancelledCount": 2,
    "paidCount": 11,
    "pendingCount": 7,
    "grossAmount": 2250.00,
    "paidAmount": 1380.00,
    "pendingAmount": 870.00
  },
  "items": [
    {
      "bookingId": 901,
      "bookingDate": "2026-03-24",
      "startTime": "16:00:00",
      "clientName": "Carlos Lima",
      "guestReference": "204",
      "treatment": "Relaxante",
      "therapistId": 33,
      "therapistName": "Ana",
      "amount": 120.00,
      "paid": true,
      "paymentMethod": "PIX",
      "paymentDate": "2026-03-24",
      "status": "SCHEDULED",
      "cancellationNotes": null
    }
  ]
}
```

### 3. Alternativa minima si se quiere reducir trabajo backend
- Extender `GET /api/v1/massages/bookings` con:
  - `dateFrom`
  - `dateTo`
  - `status`
  - `therapistId`
- Aun con esa extension, se recomienda conservar el endpoint agregado de summary.
- Motivo: el resumen por prestador es una necesidad de reporte y no debe depender de agregacion pesada en Flutter.

## Cambios backend requeridos en `quadras`

### Dominio y DTO
- Crear DTO de resumen por prestador:
  - `MassageProviderSummaryDto`
- Crear DTO de detalle del reporte:
  - `MassageProviderDetailReportDto`
  - `MassageProviderDetailItemDto`

### Repositorio
- Agregar consultas agregadas por rango de fecha y prestador.
- Preferir proyecciones/DTOs desde JPA o query dedicada para evitar cargar entidades completas innecesarias.
- Mantener consistencia de reglas:
  - montos de cancelados no se cuentan en `grossAmount`
  - pagos solo cuentan sobre `SCHEDULED`

### Servicio
- Crear servicio dedicado, por ejemplo:
  - `MassageReportService`
- Responsabilidades:
  - validar rango
  - normalizar fechas
  - calcular resumen por prestador
  - devolver detalle ordenado por fecha y hora

### Controller
- Crear controller de reportes o ampliar `MassageBookingController` con endpoints de reporte.
- Recomendacion:
  - `MassageReportController`
  - prefijo `/api/v1/massages/reports`

### Validaciones backend
- `dateFrom` obligatorio
- `dateTo` obligatorio
- `dateFrom <= dateTo`
- rango maximo sugerido para primera version:
  - `93` dias
- si `providerId` no existe, responder `404`

### Tests backend
- resumen con multiples prestadores
- resumen mezclando `SCHEDULED` y `CANCELLED`
- calculo correcto de `paidAmount` y `pendingAmount`
- detalle ordenado por fecha y hora
- rango invalido
- prestador inexistente

## Cambios frontend requeridos en `quedras-front`

### Dominio y servicio
- Agregar modelos nuevos en `lib/features/massages/domain/massage_models.dart`:
  - `MassageProviderSummary`
  - `MassageProviderReportDetail`
  - `MassageProviderReportItem`
- Extender `MassageAppService` con:
  - `listProviderSummaryReport`
  - `getProviderDetailReport`
- Implementar esos metodos en `HttpMassageAppService`.

### UI recomendada
- Mantener la card actual `Resumo do mes` como resumen ejecutivo corto.
- Debajo, agregar un bloque nuevo de reporte, por ejemplo:
  - `Resumo por prestador`
- Ese bloque debe incluir:
  - filtro de rango `data inicial / data final`
  - boton `Buscar`
  - tabla
  - panel de detalle del prestador seleccionado

### Tabla propuesta
Columnas recomendadas:
- `Prestador`
- `Atenciones`
- `Canceladas`
- `Pagas`
- `Pendentes`
- `Cobrado`
- `Pendente R$`
- `Ultimo atendimento`
- `Acoes`

Comportamiento:
- click en la fila selecciona el prestador
- la fila activa queda destacada
- no reemplazar el panel `Dia selecionado`; agregar una zona propia de detalle para no romper el flujo actual

### Panel de detalle
- Mostrar encabezado con:
  - nombre del prestador
  - rango consultado
  - chips con totales
- Debajo listar items del detalle con:
  - fecha
  - hora
  - cliente
  - habitacion/referencia
  - tratamiento
  - masajista
  - valor
  - estado
  - pago

### Reglas UX
- No remover la agenda mensual actual.
- No mezclar el detalle del reporte con el detalle del dia seleccionado.
- Si no hay datos en el rango:
  - mostrar estado vacio en tabla
  - limpiar detalle seleccionado
- Si el usuario cambia el rango:
  - invalidar seleccion previa si el prestador ya no viene en la respuesta

### Tests frontend
- parseo HTTP del resumen
- parseo HTTP del detalle
- render de tabla vacia
- seleccion de fila y carga de detalle
- preservacion de la agenda actual y del panel `Dia selecionado`
- manejo de error de API en consulta del reporte

## Plan de implementacion por fases

### Fase 1. Contrato y backend
- Definir DTO final de summary y detail.
- Implementar endpoints de reporte en `quadras`.
- Agregar tests unitarios/integracion backend.

### Fase 2. Integracion frontend
- Agregar modelos y llamadas HTTP en Flutter.
- Implementar bloque `Resumo por prestador`.
- Implementar seleccion de fila y panel de detalle.

### Fase 3. Validacion punta a punta
- Probar rango con varios prestadores.
- Probar prestador sin pagos.
- Probar prestador con cancelaciones.
- Verificar que montos y cantidades coincidan entre tabla y detalle.

## Riesgos y decisiones abiertas
- Riesgo semantico: hoy no existe estado `ATTENDED`; por eso `atenciones` debe definirse explicitamente.
- Riesgo de performance: si se usa solo `listBookings()` para todo, el frontend puede degradarse.
- Riesgo UX: si el detalle se incrusta sobre el panel diario actual, la pantalla va a quedar ambigua.

Decisiones pendientes:
- confirmar si `atenciones` significa:
  - todos los `SCHEDULED`
  - o solo los efectivamente cobrables
- confirmar si el detalle necesita paginacion
- confirmar si el rango por defecto sera:
  - mes actual
  - o ultimos `30` dias

## Criterio de cierre
- El backend expone un resumen por prestador y un detalle por prestador con rango de fechas.
- El frontend muestra tabla de resumen con montos y cantidades consistentes.
- El operador puede seleccionar un prestador y ver su detalle sin perder la agenda actual.
- La documentacion de ambos repos queda actualizada con contrato, pruebas y validacion manual.
