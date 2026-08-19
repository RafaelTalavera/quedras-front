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
- No deben convertirse en mini-resumenes del dia dentro de la celda.
- No deben listar clientes, montos ni bloques internos adicionales dentro de la agenda mensual.
- La logica visual aprobada es:
  - seleccionado: fondo calido y borde dorado
  - con actividad: fondo azul suave y borde azul profundo
  - sin actividad: fondo blanco y borde neutro

## Regla de cabecera de agenda
- La cabecera de la agenda mensual debe mantener patron operativo simple.
- Debe mostrar titulo a la izquierda y selector de mes a la derecha dentro del mismo card.
- No deben agregarse navegadores paralelos con flechas si el patron vigente ya usa selector directo.

## Regla de formularios de horario para Quadras
- El formulario de nueva reserva de `Quadras` debe priorizar seleccion simple de horario.
- `Inicio` y `Fin` deben editarse desde controles directos y faciles de leer.
- Al cambiar `Inicio`, el sistema debe proponer `Fin = Inicio + 1 hora` en el acto.
- El operador puede extender `Fin` manualmente para reservas de mayor duracion.
- `Fin` solo debe permitir horarios posteriores a `Inicio`.

## Regla de consistencia
- Este layout debe reutilizarse como patron para futuras implementaciones de calendarios dentro del sistema.
- Si se crea otro modulo con calendario, debe tomar este estandar como referencia salvo pedido explicito del usuario en sentido contrario.

## Patron de agenda temporal operativa
- La agenda temporal implementada en `Quadras` queda aprobada como referencia visual y funcional para `Quadras`, `Massagens` y `Tours`.
- Estado actual:
  - `Quadras`: implementado.
  - `Massagens`: adopcion pendiente cuando se intervenga su agenda.
  - `Tours`: adopcion pendiente cuando se intervenga su agenda.
- La vista semanal debe ser la opcion predeterminada y permanecer visible en la pantalla principal.
- Deben existir selectores para alternar entre vista `Diaria`, `Semanal` y `Mensal`.
- La vista diaria y semanal debe representar el horario operativo como una linea horizontal con barras proporcionales a la hora de inicio y fin.
- El renglon superior de la linea temporal se divide en dos mitades:
  - horario operacional a la izquierda
  - referencia de colores alineada a la derecha
- Los colores deben comunicar estados operativos equivalentes, adaptando las etiquetas al dominio de cada modulo.
- En escritorio, una reserva o actividad editable puede arrastrarse con el mouse hacia un horario libre.
- El arrastre debe:
  - ajustar el destino a intervalos operativos definidos por el modulo
  - conservar la duracion original
  - validar superposiciones antes de continuar
  - abrir la edicion con fecha y horario propuestos
  - exigir confirmacion explicita antes de persistir el cambio
- Una actividad cancelada o no editable no debe poder arrastrarse.
- La adopcion en `Massagens` y `Tours` debe preservar sus reglas de negocio, endpoints y acciones existentes; este estandar no autoriza cambios de contrato backend por si solo.
