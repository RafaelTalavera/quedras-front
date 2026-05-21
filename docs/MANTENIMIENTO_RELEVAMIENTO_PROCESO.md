# RELEVAMIENTO DE PROCESO - AREA DE MANTENIMIENTO

Fecha: 2026-04-01
Base analizada:
- `lib/features/maintenance/domain/maintenance_models.dart`
- `lib/features/maintenance/presentation/maintenance_page.dart`
- `lib/features/maintenance/application/maintenance_app_service.dart`
- `lib/features/maintenance/infrastructure/http_maintenance_app_service.dart`
- `lib/features/auth/domain/auth_session.dart`

## 1. Objetivos operativos que debe reflejar el sistema

Del relevamiento surgen dos objetivos principales:

1. Registrar y dar seguimiento a todos los trabajos de mantenimiento del hotel.
2. Convertir cada pedido en una orden operativa que llegue pendiente a mantenimiento, pueda asignarse y pueda cerrarse por un usuario del area.
3. Planificar cada orden con un tiempo de ejecucion visible en calendario para organizar la carga operativa del area.

## 2. Entradas del proceso

El proceso de mantenimiento tiene hoy dos entradas de negocio:

1. Pedido generado por un usuario del sistema con otro rol.
2. Pedido generado por un usuario del sistema en nombre de un huesped.

Regla operativa clave:
- Los pedidos realizados por o para huesped deben resolverse antes que los pedidos internos generales.

Conclusiones:
- La prioridad no puede depender solo de criticidad tecnica.
- El sistema debe distinguir el origen del pedido.
- El sistema debe poder identificar si el pedido afecta directamente a un huesped.

## 3. Estado actual del sistema

El modulo actual de mantenimiento ya resuelve una parte importante del circuito:

- Existe modulo navegable de mantenimiento.
- Existen catalogos de ubicaciones y prestadores.
- Existen ordenes con estados `OPEN`, `SCHEDULED`, `IN_PROGRESS`, `COMPLETED` y `CANCELLED`.
- Existe agenda mensual, vista por dia, historial por ubicacion, resumen y adjuntos.
- El usuario autenticado ya tiene `username` y `role` en sesion.
- La orden puede iniciarse, concluirse y cancelarse.

En el codigo actual la orden se modela principalmente con:
- ubicacion
- prestador
- prioridad
- estado
- agenda
- notas de resolucion o cancelacion

## 4. Brechas entre el sistema actual y el proceso requerido

### 4.1 Origen del pedido

Hoy la orden no registra:
- quien pidio el trabajo
- desde que rol se solicito
- si fue pedido interno o pedido en nombre de huesped
- cual huesped esta afectado

Impacto:
- no se puede priorizar correctamente la cola operativa
- no se puede separar backlog interno vs. atencion al huesped
- no se puede auditar si mantenimiento respondio primero lo que impactaba al huesped

### 4.2 Prioridad de negocio

Hoy la prioridad es generica: `LOW`, `MEDIUM`, `HIGH`, `URGENT`.

Eso no alcanza para el proceso real porque mezcla dos conceptos distintos:
- severidad tecnica
- prioridad de servicio al huesped

Recomendacion:
- mantener la severidad tecnica
- agregar prioridad operativa o clase de atencion

Ejemplo:
- `INTERNAL_STANDARD`
- `GUEST_PRIORITY`
- `CRITICAL_OPERATION`

### 4.3 Asignacion a mantenimiento

Hoy la orden exige `providerId` desde el alta.

Eso fuerza a definir el prestador antes de que exista una etapa real de recepcion y triage. Para el proceso que describiste, primero deberia existir una orden pendiente y despues su asignacion.

Falta modelar:
- usuario responsable asignado
- fecha y hora de asignacion
- cola de pendientes por usuario o equipo
- tiempo estimado o bloque de ejecucion en calendario

### 4.4 Cierre por usuario de mantenimiento

El sistema ya permite concluir una orden, pero no queda explicitado en el proceso funcional que el cierre debe ser una accion propia del area de mantenimiento o del responsable asignado.

Se recomienda definir:
- quien puede cerrar
- si puede cerrar cualquier usuario de mantenimiento o solo el asignado
- si un proveedor externo puede cerrar o solo informar ejecucion

### 4.5 Tipos de proveedor

Hoy solo existe:
- `INTERNAL`
- `EXTERNAL`

Eso es insuficiente para la operacion real. El relevamiento pide distinguir al menos:
- mantenimiento interno general
- proveedor externo de elevadores
- proveedor externo de aires acondicionados

Recomendacion:
- conservar `providerType`
- agregar `specialty` o `serviceCategory`

Valores iniciales sugeridos:
- `GENERAL_MAINTENANCE`
- `ELEVATORS`
- `AIR_CONDITIONING`

### 4.6 Modelo de ubicaciones

Hoy el catalogo de ubicaciones diferencia solo:
- `ROOM`
- `COMMON_AREA`

Esto queda corto para el mapa operativo real del hotel. El area de mantenimiento necesita una estructura escalable para crecer sin redisenar el modelo cada vez que aparezca una nueva zona.

## 5. Mapa funcional de ubicaciones relevado

### Areas comunes iniciales

- Loby
- Sala de juegos
- Sala de TV
- Dovernaca
- Reflectorio
- Estacionamiento

Nota:
- Conviene validar nomenclatura final antes de sembrar catalogos. En el relevamiento aparecen posibles variantes de escritura.

### Chalets

- Chalet 1
- Chalet 2
- Chalet 3
- Chalet 4
- Chalet 5
- Chalet 6
- Chalet 7
- Chalet 8
- Chalet 9
- Chalet 10
- Chalet 11
- Chalet 12

### Edificio principal

El edificio tiene cuatro pisos.

Cada piso debe poder tener:
- escalera
- areas comunes

Cuartos por piso:
- Piso 1: habitaciones 101 a 111
- Piso 2: habitaciones 201 a 211
- Piso 3: habitaciones 301 a 311
- Piso 4: habitaciones 401 a 407

## 6. Modelo de ubicacion recomendado

Para no dejar el catalogo atado a dos tipos rigidos, conviene pasar de un modelo plano a uno jerarquico.

Campos sugeridos:
- `siteType`: `BUILDING`, `FLOOR`, `ROOM`, `COMMON_AREA`, `CHALET`, `STAIRS`
- `parentLocationId`
- `referenceCode`
- `label`
- `floor`
- `active`

Nota UX:
- `label` debe ser la referencia principal visible para operacion diaria.
- `referenceCode` debe mantenerse como referencia interna secundaria para soporte, auditoria e integraciones.

Beneficios:
- permite agregar nuevas areas sin cambiar enums cada vez
- soporta edificio principal, pisos, escaleras, areas comunes y chalets
- mejora historial por sector
- habilita resumenes por zona

## 7. Flujo operativo recomendado

### 7.1 Recepcion del pedido

Alta del pedido con estos datos minimos:
- origen del pedido
- usuario solicitante
- rol solicitante
- si aplica, huesped afectado
- ubicacion
- descripcion
- severidad tecnica inicial
- tiempo estimado de ejecucion cuando ya se conozca

### 7.2 Triage

Mantenimiento o supervisor define:
- prioridad operativa
- responsable
- tipo de prestador
- especialidad
- agenda, si corresponde
- bloque de calendario con inicio, fin y duracion prevista de ejecucion

### 7.3 Ejecucion

La orden pasa por:
- pendiente
- asignada
- agendada
- en curso
- resuelta
- cancelada

Observacion:
- si se quiere conservar el contrato actual, `OPEN` hoy esta absorbiendo pendiente y asignada, lo cual deja el flujo poco expresivo.

### 7.4 Cierre

El usuario de mantenimiento debe poder cerrar la orden con:
- fecha y hora de cierre
- nota de resolucion
- evidencia opcional

### 7.5 Planificacion en calendario

Cada orden de mantenimiento debe poder agregarse a un calendario operativo.

Datos minimos de calendario:
- fecha de ejecucion
- hora de inicio
- hora de fin
- duracion estimada

Reglas recomendadas:
- una orden sin tiempo de ejecucion definido puede existir como pendiente
- una orden planificada debe reservar un bloque visible en el calendario
- el calendario debe permitir detectar cruces o sobrecarga del equipo
- el tiempo de ejecucion debe servir tanto para organizacion diaria como para analisis posterior

## 7.6 Resumo ejecutivo diario

Para operacion diaria no alcanza con mostrar solo lo generado en la fecha seleccionada.

Regla operativa incorporada:
- el resumen ejecutivo del dia debe mostrar tambien pendientes no cerradas de dias anteriores

Decision de implementacion:
- esta regla se resuelve en backend
- el frontend consume un resumen diario consolidado en lugar de recomponer backlog historico localmente

Motivo:
- evita diferencias entre clientes
- mantiene una sola fuente de verdad para backlog abierto
- permite que el refresco en tiempo real reutilice el mismo contrato

## 8. Estados recomendados

El modelo actual funciona, pero para el proceso relevado conviene evaluar esta semantica:

- `PENDING`: ingresada y aun no asignada
- `ASSIGNED`: asignada a mantenimiento o proveedor
- `SCHEDULED`: con agenda definida
- `IN_PROGRESS`: en ejecucion
- `COMPLETED`: resuelta y cerrada
- `CANCELLED`: anulada con motivo

Si no se quiere cambiar backend de inmediato:
- `OPEN` puede mantenerse temporalmente como `PENDING/ASSIGNED`
- pero eso deja ambiguedad operativa

## 9. Datos minimos que faltan en la orden

Campos sugeridos para el contrato:
- `requestOrigin`
- `requestedByUsername`
- `requestedByRole`
- `requestedForGuest`
- `guestName`
- `guestReference`
- `businessPriority`
- `technicalPriority`
- `assignedUserId` o `assignedUsername`
- `assignedAt`
- `providerSpecialty`
- `locationPath` o `parentLocationId`
- `scheduledStartAt`
- `scheduledEndAt`
- `estimatedExecutionMinutes`

## 10. Impacto sobre el frontend actual

### El modulo actual ya sirve como base

No hace falta rehacer la seccion. La base ya soporta:
- ordenes
- catalogos
- historial
- cierre
- resumen

### Cambios estructurales necesarios

1. El formulario de orden debe capturar origen del pedido y contexto de huesped.
2. La orden no deberia obligar prestador final en el mismo momento del alta.
3. Debe existir una vista clara de pendientes para mantenimiento.
4. El catalogo de proveedores debe incorporar especialidad.
5. El catalogo de ubicaciones debe soportar jerarquia.
6. El cierre debe quedar asociado al usuario de mantenimiento que resuelve.
7. El calendario debe mostrar el bloque de ejecucion de cada orden y no solo su existencia en el dia.

## 11. Impacto sobre backend y contrato

Este relevamiento no se resuelve solo en Flutter.

Hace falta alinear backend para:
- nuevos campos de orden
- nuevos estados o nueva semantica de estados
- jerarquia de ubicaciones
- especialidad de proveedor
- reglas de permisos para cierre
- filtros de backlog por prioridad y asignacion

## 12. Propuesta de implementacion por etapas

1. Ajustar contrato de orden para origen, huesped, asignacion y especialidad.
2. Redefinir catalogo de ubicaciones con jerarquia.
3. Adaptar formulario de alta para intake y triage real.
4. Agregar bandeja de pendientes por mantenimiento.
5. Aplicar reglas de prioridad por huesped.
6. Restringir cierre segun rol o asignacion.
7. Sembrar catalogo inicial del hotel con areas, chalets, pisos y habitaciones.

## 13. Conclusion

El sistema actual ya cubre la mecanica basica de una orden de mantenimiento, pero todavia no refleja completamente el proceso real del hotel.

La diferencia principal no esta en el calendario ni en el CRUD, sino en el modelo operativo:
- falta distinguir origen del pedido
- falta priorizar pedidos de huesped
- falta separar intake de asignacion
- falta especialidad de proveedor
- falta una estructura jerarquica de ubicaciones
- falta dejar explicito el cierre por usuario de mantenimiento

Con esos ajustes, el modulo actual puede evolucionar sin rehacerse y pasar de una agenda generica de ordenes a una herramienta alineada con la operacion real del area de mantenimiento.
