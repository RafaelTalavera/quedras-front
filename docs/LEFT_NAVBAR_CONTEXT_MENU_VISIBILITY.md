# Regla de visibilidad del submenu contextual del shell

Fecha: 2026-03-30

## Objetivo

Ocultar el submenu contextual que el shell muestra por modulo en la navegacion lateral izquierda.

Casos alcanzados:

- `Quadras`
- `Massagens`
- `Tours`

## Motivacion

El submenu contextual agregaba un segundo nivel dentro del navbar izquierdo y duplicaba accesos que ya existen dentro de la propia pantalla operativa. Para esta iteracion se prioriza una navegacion lateral mas limpia, dejando visible solo la navegacion principal del shell.

## Implementacion

La visibilidad queda centralizada en:

- `lib/features/home/presentation/shell_page.dart`
- helper: `_shouldShowSectionShortcutMenu(AuthSession? session)`

Regla actual:

- retorna `false`
- el submenu contextual no se renderiza en desktop
- el mismo submenu tampoco reaparece en el layout compacto

## Extension futura

Si mas adelante el submenu debe volver a mostrarse por rol, permiso o funcion del sistema, el punto de entrada para esa logica debe seguir siendo `_shouldShowSectionShortcutMenu(...)`.

Eso evita repartir condiciones de visibilidad entre `_NavigationPanel` y `_CompactTopBar`.
