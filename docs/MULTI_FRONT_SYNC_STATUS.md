# ESTADO ACTUAL - SINCRONIZACION MULTI-FRONT

## Arquitectura vigente
- `quadras` opera como backend API puro.
- `quedras-front` es el unico frontend operativo.
- La sincronizacion entre terminales se hace por `SSE` autenticado sobre `GET /api/v1/sync/events`.

## Modulos cubiertos
- `Massagens`
- `Quadras`
- `Tours`
- `Maintenance`

## Comportamiento implementado
- El frontend abre una conexion persistente al autenticarse.
- El backend emite eventos livianos por dominio y rango de fechas afectado.
- Cada pantalla decide si el evento impacta la vista actual y solo entonces recarga.
- Se mantiene recarga al retomar la app (`AppLifecycleState.resumed`).

## Lo que ya no aplica
- No se usa `polling` periodico en modulos operativos.
- No depende de `Timer.periodic` para detectar cambios de otras terminales.
- No hay frontend HTML/JS embebido en `quadras`.

## Uso operativo
- `local`: sigue apuntando normalmente a `http://127.0.0.1:8080/api/v1`.
- `test-red` y `prod`: varias terminales consumen la misma API y reciben cambios por eventos.

## Validacion minima
1. Abrir dos terminales contra el mismo backend.
2. Crear, editar, pagar o cancelar un registro en la terminal A.
3. Confirmar que la terminal B refleje el cambio sin esperar un intervalo fijo.
