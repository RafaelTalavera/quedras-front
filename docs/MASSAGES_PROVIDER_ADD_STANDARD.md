# ESTANDAR DE ALTA Y SELECCION DE PRESTADORES

## Estado
- Aprobado como patron para flujos de alta, seleccion, filtro y activacion de prestadores en `Massagens`.
- Puede reutilizarse como referencia para otros modulos del sistema con dialogos de gestion similares.

## Regla de cambio
- Este patron no debe modificarse por iniciativa del agente.
- Cualquier alteracion de flujo o jerarquia visual requiere instruccion explicita del usuario.

## Patron base aprobado
- El dialogo debe abrir en estado neutro.
- Ningun prestador debe quedar preseleccionado al abrir la pantalla.
- Antes de editar, el operador debe ver un resumen breve del estado actual.
- El boton principal de alta debe estar visible arriba del listado.

## Regla de seleccion y edicion
- La columna izquierda contiene el listado de tarjetas de prestadores.
- La columna derecha no debe abrir datos cargados por defecto.
- La edicion debe comenzar solo cuando el operador:
  - selecciona un prestador existente
  - o pulsa `Agregar novo prestador`
- El estado `sin seleccion` y el estado `nuevo prestador` deben tratarse como estados distintos.

## Regla de filtro
- Debe existir un filtro por nombre debajo del boton de alta.
- El filtro funciona por coincidencia parcial de cadena.
- Si la cadena escrita aparece dentro del nombre del prestador, la tarjeta permanece visible.
- El filtro no distingue mayusculas de minusculas.
- Si no hay coincidencias, la UI debe mostrar un estado vacio claro.

## Regla de tarjetas
- Las tarjetas deben ser compactas.
- Deben priorizar:
  - nombre
  - especialidad
  - contacto
  - cantidad de masajistas activos
- La tarjeta no debe crecer para mostrar detalles de edicion.
- La seleccion debe tener una referencia visual clara.

## Regla de activacion
- El control de activacion debe mostrar leyenda textual visible.
- `ON` debe verse en azul cuando el prestador esta activo.
- `OFF` debe verse en rojo cuando el prestador esta inactivo.
- El cambio de estado debe seguir apuntando al prestador correcto aunque exista filtro activo.

## Regla de consistencia
- Si otro modulo implementa un dialogo de alta con listado editable, debe tomar este patron como referencia salvo pedido explicito del usuario en sentido contrario.
