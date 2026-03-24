# ESTANDAR DE CALENDARIO DEL SISTEMA

## Estado
- Aprobado como patron visual y funcional para calendarios del sistema.
- Este layout no debe ser modificado por el agente salvo pedido explicito del usuario.

## Regla de cambio
- El agente no debe refactorizar, reinterpretar ni ajustar este layout por iniciativa propia.
- Cualquier cambio sobre este patron requiere instruccion explicita del usuario.
- Si existe duda sobre si una modificacion afecta este patron, el agente debe consultar antes de tocarlo.

## Patron base aprobado
- Estructura en una sola columna.
- Orden:
  - bloque principal o hero de la seccion
  - card de detalle del dia seleccionado
  - agenda mensual
  - resumen o metricas

## Regla de agenda mensual
- La agenda mensual debe renderizarse como calendario real.
- Siempre deben existir 7 espacios por fila.
- El dia 1 debe ubicarse en la columna correcta segun el dia de la semana.
- Deben existir celdas vacias al inicio o al cierre del mes cuando corresponda.
- Los encabezados de dias de semana deben permanecer visibles.

## Regla de tarjetas del calendario
- Las tarjetas de dias deben ser compactas.
- Deben mostrar informacion minima.
- El detalle completo del dia debe verse fuera de la tarjeta, en el panel o card de `Dia selecionado`.
- La tarjeta puede usar:
  - fecha
  - icono de referencia
  - contador o indicador minimo de reservas o atendimientos
- Los dias con reservas deben tener referencia visual propia.

## Regla de consistencia
- Este layout debe reutilizarse como patron para futuras implementaciones de calendarios dentro del sistema.
- Si se crea otro modulo con calendario, debe tomar este estandar como referencia salvo pedido explicito del usuario en sentido contrario.
