# ESTANDAR DE NAVEGACION INTERNA

## Objetivo
- Evitar micro-latencias visibles al cambiar entre modulos internos del `ShellPage`.
- Preservar estado, scroll y datos ya cargados cuando el operador cambia de seccion.
- Dejar una regla clara para futuras implementaciones de navegacion dentro del contenedor principal.

## Regla principal
- Cuando una pantalla forma parte de la navegacion interna del `ShellPage`, el cambio de seccion debe resolverse dentro del mismo arbol de widgets.
- Para esos casos se debe preferir `IndexedStack` o una estrategia equivalente de preservacion de estado.
- No debe usarse `Navigator.pushReplacementNamed` entre secciones hermanas del `ShellPage`.

## Motivo tecnico
- `pushReplacementNamed` desmonta la vista actual y monta una nueva ruta.
- Si la pantalla destino ejecuta cargas en `initState`, el cambio de modulo vuelve a disparar fetch, layout y primer render.
- Ese trabajo extra produce una pausa corta pero visible que da sensacion de lentitud.
- Mantener las pantallas vivas dentro de un `IndexedStack` elimina esa recreacion completa y hace el cambio inmediato.

## Aplicacion actual
- `lib/features/home/presentation/shell_page.dart`
- `Massagens` y `Quadras` quedan instanciadas una sola vez dentro del shell.
- El cambio de seccion actualiza solo el indice activo.
- `Tours` y `Configuracoes` tambien quedan dentro del mismo contenedor para mantener un patron unico.
- `Massagens` y `Quadras` ya usan navegacion interna secundaria dentro de la propia pagina para saltar entre bloques operativos sin perder estado ni recargar la vista.

## Criterio de implementacion
- Instanciar las paginas internas una sola vez en el estado del `ShellPage` cuando tengan carga propia o estado que convenga conservar.
- Usar `IndexedStack(index: ...)` para alternar la seccion visible.
- Mantener `Navigator` solo para cambios de flujo real:
  - login -> shell autenticado
  - logout -> login
  - dialogos, pantallas modales o flujos fuera del shell

## Que evitar
- No combinar `setState` local de seccion con `pushReplacementNamed` para el mismo cambio visual.
- No envolver arboles pesados del shell en `AnimatedSwitcher` si eso vuelve mas evidente el primer render o fuerza transiciones sobre widgets grandes.
- No reconstruir paginas de agenda o reportes en cada cambio de tab si sus datos pueden persistirse en memoria durante la sesion.

## Excepciones validas
- Si una nueva seccion necesita aislar historial propio o deep linking real por ruta, se puede evaluar otra estrategia.
- Esa excepcion debe quedar documentada en el cambio porque rompe el patron base del shell.

## Checklist para nuevas secciones
- La nueva seccion vive dentro de `ShellPage`.
- Su cambio visual no usa `pushReplacementNamed`.
- Su estado principal se conserva al volver.
- Su `initState` no se reejecuta al alternar entre modulos.
- Si necesita scroll independiente, debe manejarlo dentro de su propia pagina.
