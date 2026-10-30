# Transacciones independientes de lavandería

## Decisión funcional

El módulo maneja tres operaciones independientes:

1. **Nuevo envío**: el hotel registra las prendas que entrega a la lavandería. Se crea una remesa `STANDARD` facturable.
2. **Relavado**: el hotel registra manualmente las prendas que vuelve a enviar. Se crea una remesa `REWASH` sin costo. No depende de una recepción anterior ni conserva una línea de origen.
3. **Recibido**: el hotel registra manualmente lo que llegó de la lavandería con el mismo formulario base. Se crea una transacción `RECEIPT` independiente, sin seleccionar ni conciliar un envío anterior.

Los tres formularios aparecen en la cabecera. Debajo se muestran resúmenes separados de envíos, relavados y recepciones, además del historial general y la administración de artículos.

## Contrato

`POST /api/v1/laundry/shipments` acepta el campo opcional `kind`:

- ausente o `STANDARD`: envío normal, con precio vigente por artículo;
- `REWASH`: relavado independiente; el backend fuerza precio e importe cero.
- `RECEIPT`: recepción independiente; queda registrada directamente como recibida y sin costo.

Ejemplo de relavado:

```json
{
  "providerId": 1,
  "kind": "REWASH",
  "sentAt": "2026-10-30T18:00:00-03:00",
  "notes": "Relavado registrado por el hotel",
  "lines": [
    { "itemId": 1, "quantity": 4 }
  ]
}
```

La recepción conserva `rewashQuantity` en cero por compatibilidad del DTO existente. El backend rechaza cualquier intento de crear un relavado desde `POST /shipments/{id}/receive`.

## Compatibilidad

El cambio es compatible con clientes anteriores que crean envíos normales: si no envían `kind`, el backend utiliza `STANDARD`. Los endpoints y estados antiguos de despacho permanecen disponibles para registros históricos, pero el nuevo frontend no genera `PENDING_DISPATCH`.

## Validación

- Pruebas Flutter de las tres operaciones, serialización y resúmenes.
- Pruebas backend de creación `STANDARD`, creación `REWASH` sin costo y recepción sin relavado automático.
