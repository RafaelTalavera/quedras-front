# Memoria de Contexto Frontend - UX sin codigos como referencia principal

Ultima actualizacion: 2026-05-19

## Objetivo
Llevar la interfaz a una jerarquia visual donde el operador reconozca objetos de negocio por nombre, estado, fecha, cliente o servicio, y no por codigo interno.

## Estado por modulo
### Maintenance
- El catalogo de locales usa `Referencia interna` opcional.
- El selector de local en ordenes muestra solo el nombre.
- El codigo, cuando aparece, queda como `Ref.` secundaria.
- Los reportes ya consumen `groupKey`.

### Tours e Viagens
- El resumen y su drill-down ya consumen `groupKey` en lugar de depender del query param `code`.
- Los modelos `ToursSummaryBreakdown` y `ToursSummaryDetail` ya parsean `groupKey` con fallback a `code`.
- La pantalla principal ya abre detalle con `item.groupKey`.
- Las tarjetas y modales ahora priorizan `Prestador`, `Hospede / unidade` y `Servico do fornecedor` como lenguaje visible.

### Courts / Tennis
- El resumen de `courts` ya expone `groupKey` con compatibilidad hacia `code`.
- `tennis` usa `groupKey` para abrir detalles locales del resumen y mantener consistencia interna.
- El formulario de reservas ya usa `Hospede / unidade` como referencia operacional visible.

## Pendientes frontend
- Mantener compatibilidad visual si el backend sigue devolviendo `code` durante la transicion.
- Definir cuando conviene dejar de depender de `code` en pruebas, mocks y contratos auxiliares.

## Decision actual
- `groupKey` es la clave primaria de consumo para resumenes.
- `code` queda como fallback tecnico y compatibilidad temporal.
- Documento fuente: `docs/GROUPKEY_DEPRECATION_PLAN.md`.

## Fase B - Estado
- Iniciada.
- Los tests y mocks nuevos priorizan `groupKey`.
- `code` queda solo como respaldo minimo de compatibilidad en fixtures que aun lo necesiten.

### Avance actual
- Los contratos consumidos por frontend en `maintenance`, `tours` y `courts/tennis` ya estan alineados con `groupKey` como clave principal de resumen.
- La compatibilidad con `code` queda solo como red de seguridad mientras existan consumidores o fixtures legacy.

### Hito UX-07 - Auditoria de remanentes
- La continuidad frontend ya distingue `code` tecnico de `code` mal usado como referencia principal.
- Se documento el inventario de remanentes aceptados y pendientes en `docs/UX_GROUPKEY_AUDIT.md`.
- El siguiente foco recomendado pasa a ser tests, mocks y pantallas secundarias, no el flujo principal ya migrado.

### Hito UX-08 - Fixtures y mocks frontend
- Los tests principales de `tours` ya validan el consumo de resumen y detalle usando payloads centrados en `groupKey`, sin depender de `code`.
- Se agrego una prueba puntual de fallback legacy para conservar cobertura cuando el backend devuelva solo `code`.
- Los breakdowns fake de `tennis` ya no usan `code` como referencia principal en el escenario normal del widget test.

### Hito UX-09 - Heuristicas secundarias en maintenance
- La logica auxiliar de `maintenance_page.dart` ya prioriza `label` y contexto de piso antes que `code` para fingerprint y secuenciacion interna.
- `code` sigue disponible como referencia tecnica, pero deja de dominar incluso en heuristicas no visibles del tablero.

### Hito UX-10 - Modales y mensajes secundarios en maintenance
- Los dialogs y mensajes auxiliares de orden ya reutilizan `locationDisplayLabel`, con nombre principal del local y `Ref.` secundaria solo cuando existe.
- El resumen del local ahora expone la referencia interna como metadata discreta en lugar de forzarla como titulo principal.

### Hito UX-11 - Documentacion funcional de maintenance
- La documentacion operativa y de diseno de `maintenance` ya describe `label` como referencia principal visible y `code` o `referenceCode` como dato interno secundario.
- No se identificaron exportaciones propias de `maintenance` que contradigan este criterio en el frontend actual.

## Fuente de verdad tecnica
- Backend: `C:/Users/Public/Documents/Proyectos/quadras/docs/UX_REFERENCIAS_CONTEXTO.md`

## Comandos de validacion de este frente
- `flutter test test/features/maintenance/infrastructure/http_maintenance_app_service_test.dart`
- `flutter test test/features/tours/infrastructure/http_tours_app_service_test.dart`
- `flutter test test/features/tennis/presentation/tennis_rental_page_test.dart`
- `flutter analyze lib/features/maintenance/presentation/maintenance_page.dart`
- `flutter analyze lib/features/tours/presentation/tours_travel_page.dart`
- `flutter analyze lib/features/tennis/presentation/tennis_rental_page.dart`

## Nota de continuidad
Si se retoma este trabajo en otra sesion, el siguiente paso recomendado es revisar si conviene formalizar el mismo criterio en planes historicos mas generales o en futuras exportaciones del modulo.
