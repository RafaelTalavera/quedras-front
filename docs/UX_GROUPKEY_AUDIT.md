# Auditoria UX-07 - Remanentes de `code` en frontend

Ultima actualizacion: 2026-05-19

## Objetivo
Identificar donde `code` sigue apareciendo en frontend por compatibilidad tecnica y donde aun podia inducir a usarlo como referencia principal.

## Remanentes aceptados
- Modelos que parsean `code` como fallback mientras el backend conserve compatibilidad.
- Fixtures y mocks de tests que incluyen `code` para cubrir backward compatibility.
- Referencias internas visibles como `Ref.` en catalogos operativos donde el codigo sigue siendo util para soporte.

## Remanentes corregidos en este hito
- La memoria de continuidad ya separa contratos principales (`groupKey`) de compatibilidad legacy (`code`).
- La auditoria deja explicitado que `code` en frontend no debe guiar nuevos flujos de resumen ni nuevas pruebas de integracion.

## Remanentes a revisar despues
- Tests HTTP y mocks de resumen que hoy incluyen `code` por defecto aunque la navegacion ya use `groupKey`.
- Documentacion funcional o pantallas secundarias que puedan seguir hablando de `code` como clave de detalle.
- Exportaciones futuras que pudieran reutilizar labels tecnicos en lugar de contexto de negocio.

## Criterio actual
- Consumo nuevo:
  - `groupKey` es la clave primaria para breakdowns y drill-down.
- Compatibilidad:
  - `code` se admite como fallback tecnico, no como instruccion principal de UX ni de integracion nueva.
