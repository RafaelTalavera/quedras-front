# GUIA OPERATIVA DEL AGENTE EN FRONTEND

## Objetivo
- Definir como debe operar el agente al proponer, refactorizar o modificar pantallas, componentes y flujos del frontend.
- Evitar cambios no solicitados, interpretaciones expansivas y decisiones de producto o UX tomadas sin aprobacion del usuario.

## Regla critica de confirmacion
- El agente no debe eliminar, reemplazar, mover, ocultar, deshabilitar ni reinterpretar elementos que el usuario no haya pedido cambiar de forma explicita.
- Si la solicitud implica una posible modificacion sobre algo no pedido, el agente debe consultar antes de ejecutar el cambio.
- El agente no debe tomar decisiones autonomas sobre botones, accesos, textos, flujos o jerarquia visual cuando eso no haya sido indicado de forma clara.
- Ante ambiguedad, conflicto de interpretacion o multiples lecturas posibles, el agente debe detenerse y pedir confirmacion.

## Regla de preservacion por defecto
- Todo comportamiento existente debe preservarse por defecto.
- Si el usuario pide agregar algo nuevo, eso no autoriza a quitar o sustituir lo ya existente.
- Si el usuario pide mover una seccion o cambiar una visualizacion, el agente debe asumir primero una solucion conservadora que mantenga las acciones actuales, salvo instruccion explicita en sentido contrario.

## Regla de consulta obligatoria
- Consultar antes de cambiar acciones principales del `hero`, botones de navegacion, CTA, formularios, filtros, tabs, modales o accesos operativos.
- Consultar antes de tocar textos funcionales si el usuario no pidio copywriting.
- Consultar antes de simplificar una UI si esa simplificacion elimina capacidades existentes.
- Consultar antes de convertir una interpretacion en cambio permanente.

## Regla de respuesta
- Cuando el agente detecte que hay una parte ambigua, debe explicitar la duda en una frase corta y pedir confirmacion concreta antes de editar.
- El agente debe diferenciar entre:
  - cambio pedido por el usuario
  - cambio inferido por conveniencia tecnica
  - cambio opcional sugerido
- Los cambios inferidos u opcionales no deben ejecutarse sin aprobacion.

## Regla critica de cambios compartidos con backend
- Si el cambio pedido afecta entidades, endpoints, payloads, respuestas JSON o reglas de negocio compartidas con backend, el agente no puede trabajar solo en frontend.
- En esos casos debe identificar primero el repo backend correspondiente y abrir un alcance dual `frontend + backend`.
- El cambio no se considera resuelto si solo se implementa UI o cliente HTTP.
- Antes de cerrar un cambio compartido, el agente debe verificar explicitamente:
  - repo frontend tocado
  - repo backend tocado
  - contrato request/response actualizado en ambos lados
  - prueba manual o automatizada punta a punta
- Si por cualquier motivo no puede tocar el backend en ese turno, debe detener el cierre y declarar el cambio como incompleto.

## Aplicacion especifica a Massagens
- Todo cambio sobre `prestadores`, `masajistas`, `bookings`, `payment`, `cancel` o `audit` debe tratarse como cambio compartido con backend.
- El backend de referencia para este modulo es [quadras](/c:/Users/Public/Documents/Proyectos/quadras).
- No se debe marcar como cerrado un cambio de `Massagens` mientras no exista validacion real del contrato backend.

## Aplicacion especifica a incidentes de UI
- Si existe un boton actual y el usuario no pidio eliminarlo, el boton debe permanecer.
- Si el usuario pide agregar un nuevo acceso o resumen, eso no autoriza a remover otro acceso existente.
- Si el usuario pide refactorizar la visualizacion, el agente debe preservar primero la funcionalidad actual y luego proponer mejoras separadas si hacen falta.

## Regla de patrones cerrados
- Cuando el usuario indique que un layout, flujo o patron queda cerrado como estandar del sistema, el agente debe tratarlo como base congelada.
- El agente no debe modificar un patron cerrado salvo pedido explicito del usuario.
- Los calendarios del sistema deben seguir el documento `docs/CALENDAR_LAYOUT_STANDARD.md`.

## Prioridad de esta guia
- Esta guia aplica a cualquier intervencion del agente sobre frontend dentro de este repositorio.
- Si una instruccion futura del usuario contradice esta guia, prevalece la instruccion explicita del usuario para ese caso puntual.
