# ESTANDAR DE SIDEBAR DESKTOP

## Objetivo
- Mantener el panel izquierdo estable, legible y sin `RenderFlex overflow`.
- Permitir que el sidebar soporte modulos con submenus internos sin romper la composicion visual del shell.

## Estructura base
- El sidebar desktop mantiene dos niveles:
  - bloque institucional superior
  - navegacion operativa inferior
- El orden visual debe ser:
  - marca
  - sesion
  - submenu contextual opcional
  - navegacion principal
  - salida

## Parametros de diseno
- Ancho total del sidebar desktop: `302 px`
- Ancho util de navegacion lateral: `236-266 px`
- Radio del panel principal: `28 px`
- Padding vertical superior base: `24 px`
- Padding vertical superior compacto: `18 px`
- Separacion inferior del bloque de sesion:
  - normal: `18 px`
  - compacta: `12 px`
- Separacion inferior del bloque contextual:
  - normal: `14 px`
  - compacta: `12 px`
- El bloque `Sessao ativa` debe mantenerse deliberadamente compacto:
  - sin textos institucionales extra debajo del logo
  - con username en una sola linea
  - con pill de estado reducible u ocultable segun altura disponible

## Reglas por altura
- `>= 880 px`
  - usar header normal
  - mostrar descripcion del submenu contextual
  - mostrar pill de estado de sesion
- `760-879 px`
  - usar header compacto
  - mantener submenu contextual
  - ocultar elementos secundarios que no cambian la operacion
- `< 760 px`
  - usar header compacto
  - ocultar descripcion secundaria del submenu
  - ocultar pill de estado de sesion
  - la navegacion principal debe ser scrollable

## Reglas de comportamiento
- Si se agrega un submenu contextual, no debe empujar la navegacion principal fuera de pantalla.
- La navegacion principal debe degradar con scroll vertical controlado antes de producir overflow.
- Los textos de identidad o sesion que puedan crecer deben truncarse con `maxLines: 1` y `TextOverflow.ellipsis`.
- Los bloques secundarios del sidebar deben poder compactarse sin alterar la jerarquia principal.

## Aplicacion actual
- `lib/features/home/presentation/shell_page.dart`
- Header institucional reducido:
  - sin `Hotel Costa Norte`
  - sin `Servicos internos do hotel`
- Modulo `Quadras` usa submenu contextual enlazado a:
  - `Dia selecionado`
  - `Agenda mensal`
  - `Resumo do periodo`

## Checklist antes de cerrar cambios en sidebar
- Validar desktop alto.
- Validar desktop con altura intermedia.
- Validar desktop con ventana baja.
- Confirmar ausencia de `RenderFlex overflow`.
- Confirmar que el submenu contextual no tape ni expulse la navegacion principal.
