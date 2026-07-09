# MANUTENCAO UI COMPACT UPDATE - 2026-07-09

## Alcance
- Ajuste visual incremental de `Manutencao` sin cambio de servicios, endpoints ni acciones operativas.
- Objetivo: reducir carga visual inicial y compactar los bloques mas usados del modulo.

## Cambios aplicados
- Hero superior simplificado:
  - `Operacao tecnica` paso a `Manutencao`
  - se removio `Manutencao do hotel`
  - se removio el parrafo descriptivo
  - se redujo la separacion vertical entre el label superior y los botones
- Nav lateral desktop:
  - se redujo aproximadamente 15% el ancho del sidebar para ganar area de contenido
- Estado de ordenes:
  - `Resumo executivo do dia` paso a `Estado de ordenes`
  - `Ordens abertas` paso a `Abiertas`
  - se elimino el card superior `Pendientes`
  - se removio el subtitulo descriptivo dentro del cuadro de detalle
  - se removio el aviso de ordens arrastradas de dias anteriores
  - los chips de estado quedaron justificados en una sola fila
- Compactacion visual del modulo:
  - menos padding en cards principales e internos
  - radios mas contenidos
  - menor separacion vertical entre bloques
  - chips metricos mas compactos
  - tarjetas de locales mas compactas

## Funcionalidad preservada
- Lanzar orden
- Nuevo preventivo
- Catalogos
- Alterar dia
- Apertura de detalle de orden
- Historiales
- Anexos
- Exportacion PDF
- Impresion

## Archivos tocados
- `lib/core/widgets/brand_section_hero.dart`
- `lib/features/home/presentation/shell_page.dart`
- `lib/features/maintenance/presentation/maintenance_page.dart`

## Validacion ejecutada
- `dart format lib/core/widgets/brand_section_hero.dart lib/features/maintenance/presentation/maintenance_page.dart`

## Validacion pendiente
- Revision visual en desktop y resoluciones intermedias para confirmar balance de anchos y densidad.
