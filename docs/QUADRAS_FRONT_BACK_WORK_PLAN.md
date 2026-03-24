# PLAN DE TRABAJO QUADRAS

## Objetivo
- Reemplazar el flujo actual de `tennis` basado en `reservations` genericas por un modulo propio de `Quadras`, tomando como referencia funcional y visual el modulo `Massagens`.
- Mantener el patron visual aprobado del sistema:
  - `hero`
  - card de `Dia selecionado`
  - agenda mensual
  - resumen o metricas

## Analisis del estado actual
- El frontend ya tiene un patron maduro en `Massagens` para:
  - agenda mensual
  - detalle del dia
  - alta operativa
  - cancelacion
  - pago
  - resumenes
- La seccion `tennis` actual no tiene dominio propio.
- `tennis_rental_page.dart` hoy solo alterna entre agenda y alta de `reservations`.
- `reservations` no soporta:
  - tipo de cliente
  - tarifario editable
  - materiales cobrables
  - diferencia entre huesped, VIP, externo y profesor parceiro
  - estado de pago con modalidad
  - snapshot de precios aplicados al momento de reservar

## Reglas funcionales confirmadas
- Huesped del hotel:
  - reserva cancha sin costo
  - materiales en prestamo sin costo
- Usuario externo:
  - puede alquilar en horario diurno y nocturno
  - paga cancha y materiales usados
- Valores editables:
  - tarifa diferencial para profesor de tenis parceiro del hotel
  - tarifa externo diurno: `60 BRL`
  - tarifa externo nocturno: `80 BRL`
  - todos los valores deben poder editarse
- VIP:
  - debe existir como tipo distinto de huesped
  - representa al dueno del hotel
  - no paga tarifa de cancha
  - debe computar horas en resumenes y controles
- Materiales:
  - `Raqueta`: `20 BRL` por unidad
  - `Pelota`: `10 BRL` por unidad
  - el uso es en caracter de prestamo
  - huespedes no pagan materiales
  - usuarios externos pagan por uso de materiales prestados
- Pago:
  - debe existir `pagado` y `no pagado`
  - debe registrarse la modalidad de pago
- Horas:
  - todos los resumenes deben incluir horas reservadas
  - el control de horas debe segmentarse por tipo de usuario
- Cambio `DAY` / `NIGHT`:
  - no se define con una hora fija anual
  - debe regirse por estimaciones de salida y puesta del sol para Florianopolis
  - la regla debe contemplar estacionalidad
  - referencia operativa inicial:
    - alrededor del equinoccio de marzo de 2026: amanecer `06:17` y atardecer `18:25`
    - alrededor del solsticio de junio de 2026: amanecer `07:04` y atardecer `17:27`
    - alrededor del solsticio de diciembre de 2026: amanecer `05:15` y atardecer `19:09`

## Decision de arquitectura
- No extender `reservations` para cubrir Quadras.
- Crear un dominio nuevo en frontend y backend, equivalente al patron de `Massagens`.
- Motivo:
  - las reglas de pricing y facturacion ya no son genericas
  - el modelo necesita items de materiales y snapshot tarifario
  - los reportes operativos van a ser distintos

## Modelo funcional propuesto

### Tipos de cliente
- `GUEST`
- `VIP`
- `EXTERNAL`
- `PARTNER_COACH`

### Periodo tarifario
- `DAY`
- `NIGHT`

### Estado de reserva
- `SCHEDULED`
- `CANCELLED`

### Estado de pago
- `UNPAID`
- `PAID`

### Modalidad de pago
- `PIX`
- `CARD`
- `CASH`
- `COURTESY`
- `TRANSFER`

### Materiales
- `RACKET`
- `BALL`

## Contrato minimo esperado del backend

### Tarifa editable
- entidad de configuracion con:
  - `customerType`
  - `period`
  - `amount`
  - `active`
  - `updatedAt`
  - `updatedBy`

### Material editable
- entidad de configuracion con:
  - `code`
  - `label`
  - `unitPrice`
  - `chargeGuest`
  - `chargeVip`
  - `chargeExternal`
  - `chargePartnerCoach`
  - `active`

### Reserva de quadra
- campos minimos:
  - `id`
  - `bookingDate`
  - `startTime`
  - `endTime`
  - `durationMinutes`
  - `customerName`
  - `customerReference`
  - `customerType`
  - `pricingPeriod`
  - `sunriseEstimate`
  - `sunsetEstimate`
  - `courtAmount`
  - `materialsAmount`
  - `totalAmount`
  - `paid`
  - `paymentMethod`
  - `paymentDate`
  - `paymentNotes`
  - `status`
  - `cancellationNotes`
  - `materials`
  - `createdAt`
  - `updatedAt`
  - `cancelledAt`
  - `createdBy`
  - `updatedBy`
  - `cancelledBy`

### Item de material reservado
- `materialCode`
- `materialLabel`
- `quantity`
- `unitPrice`
- `totalPrice`

## Alcance frontend

### Fase 1. Dominio y cliente HTTP
- Crear feature `lib/features/courts/`.
- Agregar:
  - `court_models.dart`
  - `court_app_service.dart`
  - `http_court_app_service.dart`
- Mantener `tennis` solo como punto de entrada visual hasta migrar el route.

### Fase 2. Pantalla operativa
- Reemplazar la pantalla actual de `tennis` por una pagina de Quadras basada en el patron de `Massagens`.
- Layout obligatorio:
  - `BrandSectionHero`
  - card `Dia selecionado`
  - agenda mensual de 7 columnas
  - resumen inferior
- Acciones minimas:
  - `Lancar reserva`
  - `Cancelar reserva`
  - `Informar pago`
  - `Tarifas y materiales`

### Fase 3. Formulario de reserva
- Campos:
  - fecha
  - hora inicio
  - hora fin
  - nombre
  - referencia
  - tipo de cliente
  - periodo tarifario autocalculado con override controlado
  - materiales con cantidad
  - total calculado
  - pagado / no pagado
  - modalidad de pago
  - notas
- Reglas de UI:
  - si `GUEST`, materiales deben mostrarse con valor `0`
  - si `EXTERNAL`, mostrar valor de cancha segun `DAY` o `NIGHT`
  - si `VIP`, usar tarifa propia editable
  - si `PARTNER_COACH`, usar tarifa diferencial editable

### Fase 4. Configuracion operativa
- Dialogo o pantalla para:
  - editar tarifas por tipo y periodo
  - editar materiales y valores unitarios
  - activar o desactivar configuraciones

### Fase 5. Resumen y reportes
- Totales del mes:
  - reservas activas
  - canceladas
  - horas reservadas
  - ingresos cobrados
  - ingresos pendientes
  - materiales prestados
- Tabla por tipo de cliente y por modalidad de pago
- Todas las vistas de resumen deben incluir horas por:
  - `GUEST`
  - `VIP`
  - `EXTERNAL`
  - `PARTNER_COACH`

## Alcance backend
- El detalle tecnico backend queda documentado en:
  - [QUADRAS_BACKEND_PLAN.md](/c:/Users/Public/Documents/Proyectos/quadras/docs/QUADRAS_BACKEND_PLAN.md)

## Riesgos y decisiones pendientes
- Debe confirmarse si una reserva puede incluir mas de una cancha en el futuro.
- Debe definirse si el modulo tomara estimacion solar:
  - por fecha exacta
  - por tabla mensual
  - por integracion externa o libreria astrononomica local
- Debe confirmarse si `PARTNER_COACH` paga o no materiales cuando los usa.

## Orden recomendado de ejecucion
1. Backend: modelo, migraciones, endpoints y tests.
2. Frontend: modelos, cliente HTTP y mocks de integracion.
3. Frontend: pantalla de Quadras sobre contrato real.
4. Validacion punta a punta con pago, cancelacion y materiales.

## Criterio de cierre
- Frontend y backend exponen el mismo contrato para Quadras.
- La UI respeta el patron visual aprobado del sistema.
- La reserva calcula importes correctamente segun tipo de cliente, periodo y materiales.
- El pago queda trazado con estado y modalidad.
- Existe evidencia manual o automatizada de flujo completo:
  - crear
  - pagar
  - cancelar
  - listar en agenda y resumen
