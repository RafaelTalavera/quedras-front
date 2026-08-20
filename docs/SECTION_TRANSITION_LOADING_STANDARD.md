# Indicador de carga entre secciones

La navegación principal muestra una capa de carga al cambiar entre Quadras,
Massagens, Tours, Manutenção y Configuración.

## Comportamiento

- La capa aparece antes de sustituir el contenido y desaparece después del
  primer frame de la nueva sección.
- Durante la transición se bloquean nuevas selecciones para evitar dobles
  navegaciones.
- El texto anuncia la sección de destino y se expone como una región activa
  para tecnologías de asistencia.
- La transición usa un tiempo breve y fijo; no reemplaza los indicadores de
  carga internos asociados a consultas de datos.

## Diseño

El fondo aplica desenfoque y una capa azul translúcida. La tarjeta usa blanco,
bordes redondeados y un indicador circular azul con pista dorada, siguiendo la
paleta definida en `CostaNorteBrand`.
