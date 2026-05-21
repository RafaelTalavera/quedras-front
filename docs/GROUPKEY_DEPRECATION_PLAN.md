# Plan frontend para transicion de `code` a `groupKey`

Ultima actualizacion: 2026-05-19

## Regla de consumo
- Si el backend expone `groupKey`, el frontend debe usar `groupKey`.
- `code` queda solo como fallback de parseo o metadata tecnica.

## Estado actual
- `maintenance`: consume `groupKey` en reportes.
- `tours`: consume `groupKey` en reportes y detail.
- `courts/tennis`: consume `groupKey` en breakdown local del resumen.

## Politica de frontend
- No agregar nueva logica de negocio basada en `item.code` en modulos de resumen.
- Mantener parseo con fallback `groupKey ?? code` mientras el backend siga en transicion.
- Donde el usuario vea una referencia visible, preferir nombre/label/contexto operacional.

## Pendiente de limpieza futura
- Migrar fixtures y aserciones viejas para que `groupKey` sea la validacion principal.
- Reducir dependencia de `code` en pruebas auxiliares cuando ya no aporte cobertura real.

## Fuente de verdad
- Backend: `C:/Users/Public/Documents/Proyectos/quadras/docs/GROUPKEY_DEPRECATION_PLAN.md`
