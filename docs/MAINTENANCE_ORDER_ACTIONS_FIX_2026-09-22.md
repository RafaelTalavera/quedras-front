# Mantenimiento: correccion de acciones operativas

Fecha: 2026-09-22

## Problema corregido

Las acciones para iniciar, concluir o cancelar una orden no llegaban al backend
en dos escenarios:

1. La confirmacion reutilizable resolvia la accion como cancelada al cerrar el
   dialogo, antes de invocar el callback positivo.
2. Las ordenes pendientes de dias anteriores aparecen en `Estado das ordens` y
   en el `Mapa operacional`, pero no pertenecen a la lista filtrada por el dia
   seleccionado. Las acciones las buscaban en esa lista y terminaban sin hacer
   la solicitud HTTP.

## Cambio aplicado

- `AppAlerts.confirm` espera un ciclo de eventos antes de interpretar el cierre
  como cancelacion, permitiendo que el callback de `Confirmar` resuelva la
  accion como aprobada.
- Las acciones `Iniciar`, `Concluir`, `Cancelar` y `Anexos` reciben la orden
  abierta en el dialogo. Ya no dependen de buscarla por ID en la lista diaria.
- No hubo cambios en el contrato backend: iniciar conserva
  `PATCH maintenance/orders/{id}/start` y concluir conserva
  `PATCH maintenance/orders/{id}/complete`.

## Cobertura de regresion

`test/features/maintenance/presentation/maintenance_order_actions_test.dart`
valida que una orden arrastrada ejecute `Iniciar` con su ID correcto desde:

- `Estado das ordens`.
- `Mapa operacional`.

Validacion ejecutada: 2 pruebas Flutter exitosas. El analisis estatico no
reporta errores nuevos; los avisos restantes son deprecaciones preexistentes
en la pantalla de mantenimiento.
