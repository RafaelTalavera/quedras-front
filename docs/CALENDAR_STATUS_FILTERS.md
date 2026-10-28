# Filtros de estado en calendarios operativos

Las referencias de color de los calendarios operativos funcionan también como
filtros de eventos.

## Comportamiento

- Al seleccionar una referencia, el calendario muestra únicamente los eventos
  de ese estado.
- La referencia activa se distingue con borde, texto reforzado y un icono de
  confirmación.
- Al seleccionar nuevamente la referencia activa, el filtro se limpia y se
  muestran todos los eventos.
- Cada control incluye una ayuda contextual y expone su estado seleccionado a
  las tecnologías de asistencia.

## Estados por módulo

- Quadras: `Reservado`, `Pendente` y `Cancelado`.
- Massagens: `Pago`, `Pendente` y `Cancelado`.
- Tours: `Pago`, `Pendente` y `Cancelado`.

En los tres módulos, los estados cancelados tienen prioridad sobre el estado de
pago. Por lo tanto, un evento cancelado nunca aparece en los filtros `Pago`,
`Reservado` o `Pendente`.

Manutenção no utiliza actualmente una leyenda de estados equivalente.
