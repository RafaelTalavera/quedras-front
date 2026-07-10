# MANUTENCAO UI SIMPLIFICATION - 2026-07-10

## Alcance
- Continuacion de la limpieza visual del modulo `Manutencao`.
- Objetivo: reducir carga en la pantalla principal y mover la operacion preventiva a un acceso dedicado.

## Cambios aplicados
- Preventivos:
  - el boton superior `Novo preventivo` pasa a `Preventivos`
  - el boton ya no abre solo el alta
  - ahora abre un dialogo dedicado con:
    - listado de planes
    - metricas de planes
    - `Criar plano`
    - `Editar`
    - `Gerar ordem`
- Vista general:
  - se elimina el card `Planos preventivos`
  - se elimina el card `Resumo por local`
  - se eliminan las secciones internas `Andares` y `Chales`
  - la vista principal queda concentrada en el resumen ejecutivo y en la botonera operativa

## Funcionalidad preservada
- Lanzar orden
- Preventivos:
  - crear plan
  - editar plan
  - generar orden desde plan
  - consultar metricas y listado de planes
- Catalogos
- Alterar dia
- Exportacion e impresion del resumen diario
- Acciones rapidas sobre ordens

## Limpieza tecnica
- se removio estado local y helpers privados que solo alimentaban la antigua vista por local
- se elimino carga innecesaria de planes en la pantalla principal
- se conservaron los servicios y contratos existentes; no hubo cambios de API

## Archivo principal tocado
- `lib/features/maintenance/presentation/maintenance_page.dart`

## Validacion ejecutada
- `dart format lib/features/maintenance/presentation/maintenance_page.dart`
- `flutter analyze lib/features/maintenance/presentation/maintenance_page.dart`
