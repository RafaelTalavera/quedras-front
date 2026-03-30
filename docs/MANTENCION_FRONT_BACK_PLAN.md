# PLAN FRONTEND MANTENCION

Fecha: 2026-03-30
Modulo propuesto: `maintenance`
Estado: `Implementado`
Backend relacionado: `C:/Users/Public/Documents/Proyectos/quadras`

## Estado final implementado
- Se incorporo la seccion `Manutencao` al shell principal.
- Se implementaron:
  - calendario mensual
  - panel de dia seleccionado
  - CRUD operativo de ordenes
  - catalogos de ubicaciones y responsables
  - historial por ubicacion
  - resumen estandar con detalle
  - fotos y adjuntos
- Politica confirmada para conflictos de agenda por ubicacion:
  - no bloquear automaticamente
  - mostrar alerta de conflicto
  - dejar continuar si el operador confirma
- Validacion ejecutada:
  - `flutter analyze lib/features/maintenance lib/features/home/presentation/shell_page.dart lib/app lib/core/network`

## Objetivo
- Agregar una nueva seccion de `mantencion` al frontend.
- Reusar la misma estetica y la misma logica operativa que hoy usan `massages`, `tours` y `quadras`.
- Soportar:
  - agenda con calendario
  - panel de dia seleccionado
  - alta y seguimiento de ordenes
  - mantenimiento de catalogos
  - resumen de periodo
  - historial por cuarto o area comun

## Base analizada del sistema actual
- El shell actual ya trabaja con modulos independientes:
  - `Massagens`
  - `Quadras`
  - `Tours`
- Cada modulo mantiene el patron visual aprobado:
  - hero
  - card de `Dia selecionado`
  - agenda mensual
  - resumen o metricas
- El sidebar y los menus internos ya cambian por modulo.
- El frontend tambien ya tiene un patron tecnico repetible:
  - `domain/*_models.dart`
  - `application/*_app_service.dart`
  - `infrastructure/http_*_app_service.dart`
  - `presentation/*_page.dart`

## Decision de arquitectura
- Crear feature nueva: `lib/features/maintenance/`.
- No mezclar `mantencion` dentro de `settings`, `massages`, `tours` o `courts`.
- Mantener el contrato alineado con el backend propuesto bajo `/api/v1/maintenance`.
- Reusar el estandar de calendario documentado en:
  - `docs/CALENDAR_LAYOUT_STANDARD.md`

## Alcance funcional propuesto

### 1. Catalogo de ubicaciones
- Debe existir gestion para:
  - cuartos
  - areas comunes
- Acciones minimas:
  - listar
  - crear
  - editar
  - activar o desactivar

### 2. Catalogo de responsables
- Debe existir gestion para:
  - mantenimiento interno
  - mantenimiento externo
- El usuario debe poder identificar:
  - nombre
  - tipo
  - servicio que presta
- Registros iniciales visibles:
  - mantenimiento interno
  - servicio de mantenimiento de aires
  - servicio de mantenimiento de internet

### 3. Ordenes operativas
- El usuario debe poder:
  - crear orden
  - editar orden
  - iniciar trabajo
  - completar trabajo
  - cancelar trabajo
- La orden debe mostrar:
  - ubicacion
  - responsable
  - descripcion
  - prioridad
  - estado
  - agenda
  - notas de resolucion o cancelacion

### 4. Historia por cuarto o area comun
- Debe existir acceso directo al historico de cada ubicacion.
- La recomendacion es resolverlo con:
  - un modal o panel secundario desde el bloque del dia y desde el calendario
- El historico debe mostrar:
  - fecha reportada
  - agenda
  - responsable
  - estado
  - resolucion

### 5. Fotos y adjuntos
- La orden debe permitir:
  - subir fotos
  - subir adjuntos
  - visualizar archivos ya cargados
  - eliminar archivos cuando la regla de negocio lo permita
- Usos iniciales:
  - foto del problema
  - foto del resultado
  - comprobante o factura del proveedor
  - documento tecnico relacionado
### 6. Resumen estandar
- Debe seguir el mismo criterio visual del sistema.
- KPIs sugeridos:
  - abiertas
  - agendadas
  - en curso
  - completadas
  - canceladas
  - internas
  - externas
  - urgentes
- Breakdown sugerido:
  - por responsable
  - por tipo de responsable
  - por tipo de ubicacion
  - por estado

## Contrato frontend esperado

### Modelos
- `maintenance_models.dart`
- Enums sugeridos:
  - `MaintenanceLocationType`
  - `MaintenanceProviderType`
  - `MaintenanceOrderStatus`
  - `MaintenancePriority`
- Entidades sugeridas:
  - `MaintenanceLocation`
  - `MaintenanceProvider`
  - `MaintenanceOrder`
  - `MaintenanceSummaryReport`
  - `MaintenanceSummaryBreakdown`
  - `MaintenanceSummaryDetail`

### Servicio de aplicacion
- `maintenance_app_service.dart`
- Operaciones minimas:
  - `listLocations`
  - `createLocation`
  - `updateLocation`
  - `getLocationHistory`
  - `listProviders`
  - `createProvider`
  - `updateProvider`
  - `listOrders`
  - `createOrder`
  - `updateOrder`
  - `startOrder`
  - `completeOrder`
  - `cancelOrder`
  - `getSummaryReport`
  - `getSummaryDetails`

### Infraestructura HTTP
- `http_maintenance_app_service.dart`
- Debe seguir el mismo estilo que `HttpCourtAppService`, `HttpMassageAppService` y `HttpToursAppService`:
  - headers JSON
  - manejo uniforme de errores
  - parseo tipado

## UI recomendada

### Ruta y navegacion
- Agregar nueva ruta:
  - `AppRoutes.maintenance`
- Agregar nueva seccion del shell:
  - `AppSection.maintenance`
- Mantener el orden del menu consistente con la operacion del hotel.
- Recomendacion:
  - `Massagens`
  - `Quadras`
  - `Tours`
  - `Mantencao`
  - `Config.`

### Pagina principal
- Archivo sugerido:
  - `lib/features/maintenance/presentation/maintenance_page.dart`
- Debe copiar el patron estructural ya aprobado:
  - `BrandSectionHero`
  - card `Dia selecionado`
  - agenda mensual
  - resumen del periodo

### Hero
- Eyebrow sugerido:
  - `Operacao tecnica`
- Titulo sugerido:
  - `Mantencao do hotel`
- Acciones minimas:
  - `Lancar ordem`
  - `Iniciar`
  - `Concluir`
  - `Cancelar`
  - `Catalogos`
  - `Atualizar`

### Card `Dia selecionado`
- Debe mostrar:
  - total de ordenes del dia
  - abiertas o pendientes
  - en curso
  - completadas
- Debe listar tarjetas compactas de ordenes del dia.
- Cada tarjeta debe mostrar:
  - ubicacion
  - responsable
  - estado
  - horario
  - prioridad

### Agenda mensual
- Debe respetar el estandar de calendario del repo.
- Las celdas no deben convertirse en mini reportes.
- Cada dia debe mostrar solo:
  - contador
  - indicador visual de urgencia cuando aplique
  - referencia rapida de actividad

### Resumen del periodo
- Debe mantener el bloque tipo `Resumo do periodo`.
- Debe incluir:
  - filtro `inicio / fim`
  - boton `Buscar`
  - cards KPI
  - tablas de breakdown
  - detalle por fila en modal

## Dialogos o paneles necesarios

### Dialogo de orden
- Campos minimos:
  - ubicacion
  - responsable
  - titulo
  - descripcion
  - prioridad
  - fecha
  - hora inicio
  - hora fin
  - estado inicial
- Reglas:
  - si solo se reporta la ocurrencia, debe poder quedar `OPEN`
  - si ya tiene agenda, debe poder salir `SCHEDULED`

### Dialogo de catalogos
- Puede ser una unica ventana con tabs o segmentos:
  - `Ubicacoes`
  - `Responsaveis`
- Debe permitir crear y editar sin romper el flujo principal.

### Dialogo de historial
- Acceso desde:
  - tarjeta del dia
  - tabla de resumen
  - gestion de ubicaciones
- Debe listar el historico de una ubicacion en orden cronologico inverso.

### Dialogo o bloque de adjuntos
- Debe existir dentro del detalle de la orden o en un modal dedicado.
- Debe soportar:
  - galeria de fotos
  - lista de archivos adjuntos
  - accion `Agregar arquivo`
  - accion `Excluir` cuando corresponda
- Debe dejar claro quien subio el archivo y cuando.

### Dialogo de cierre
- Para cerrar la orden debe pedir:
  - fecha/hora de cierre
  - nota de resolucion

### Dialogo de cancelacion
- Debe pedir:
  - motivo obligatorio

## Fases de implementacion recomendadas
1. Crear feature `maintenance` con modelos y app service.
2. Implementar cliente HTTP sobre el contrato backend.
3. Implementar soporte de seleccion y envio de fotos y adjuntos.
4. Agregar ruta y nueva entrada en `ShellPage`.
5. Montar pagina principal con el layout estandar del sistema.
6. Implementar dialogos de orden, cierre y cancelacion.
7. Implementar dialogo de catalogos para ubicaciones y responsables.
8. Implementar historial por ubicacion.
9. Implementar bloque de adjuntos por orden.
10. Implementar resumen estandar y detalle por grupo.
11. Validar responsive y sincronizacion con auto refresh.

## Validaciones UX y tecnicas
- No romper el patron visual aprobado del calendario.
- No mezclar el historial con el panel principal del dia si eso vuelve ambigua la pantalla.
- No cargar toda la logica de resumen en Flutter cuando el backend ya debe devolver agregados.
- Mantener el auto refresh con el mismo criterio operativo de los otros modulos.
- Mantener dialogos en el estandar del repo:
  - dimensiones
  - alertas
  - copy operacional

## Riesgos y decisiones abiertas
- Confirmar si el label visible debe quedar en portugues:
  - `Mantencao`
  - o en espanol:
  - `Mantencion`
- Confirmar si la vista principal debe mostrar primero solo ordenes del dia o tambien backlog abierto sin agenda.
- Confirmar si el cierre debe permitir recalificar prioridad o responsable final.
- Confirmar si el calendario debe marcar sobrecarga visual para ordenes `URGENT`.

## Dependencias con backend
- Este plan depende del contrato documentado en:
  - `C:/Users/Public/Documents/Proyectos/quadras/docs/MANTENCION_BACKEND_PLAN.md`
- El frontend no debe inventar estados ni breakdowns que no existan en backend.

## Criterio de cierre
- Existe una nueva seccion navegable de `mantencion`.
- La pantalla respeta el patron:
  - hero
  - dia seleccionado
  - agenda mensual
  - resumen del periodo
- El operador puede:
  - administrar ubicaciones
  - administrar responsables
  - crear y seguir ordenes
  - consultar historial por ubicacion
  - consumir resumenes del periodo
