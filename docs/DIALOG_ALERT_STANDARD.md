# DIALOG & ALERT STANDARD - COSTANORTE

## Objetivo
- Definir un estandar unico para dialogos y avisos al usuario en el frontend Flutter.
- Evitar modales demasiado anchos o inconsistentes entre modulos.
- Concentrar la experiencia visual en componentes reutilizables.

## Estandar vigente
- Todos los avisos operativos al usuario deben usar `AppAlerts`.
- `AppAlerts` es el wrapper oficial sobre `awesome_dialog`.
- No se deben crear nuevos `SnackBar` o modales ad hoc para exito, error, warning, info o confirmacion si el caso entra en `AppAlerts`.

## Tipos de aviso
- `success`: operacion completada correctamente.
- `error`: fallo de persistencia, validacion remota o integracion.
- `warning`: bloqueo o advertencia operativa antes de continuar.
- `info`: mensaje neutral o contextual.
- `confirm`: confirmacion previa a una accion sensible.

## Anchos estandar
- `alertWidth = 420`: alertas compactas y confirmaciones.
- `compactFormWidth = 540`: formularios cortos.
- `standardFormWidth = 580`: formularios operativos principales.
- `wideFormWidth = 680`: dialogs con mas densidad de contenido, pero sin expandirse de forma excesiva.

Los valores viven en `lib/core/widgets/app_dialog_dimensions.dart`.

## Widgets reutilizables oficiales
- `AppAlerts`
  Archivo: `lib/core/feedback/app_alerts.dart`
  Uso: alertas y confirmaciones modales con estilo CostaNorte.

- `AppDialogShell`
  Archivo: `lib/core/widgets/app_dialog_shell.dart`
  Uso: base reusable para dialogs propios con ancho, alto maximo y padding estandarizados.

- `AppDialogDimensions`
  Archivo: `lib/core/widgets/app_dialog_dimensions.dart`
  Uso: catalogo central de anchos estandar para dialogs y alertas.

## Regla de implementacion
- Si el caso es un aviso modal, usar `AppAlerts`.
- Si el caso es un formulario o dialog custom, envolverlo con `AppDialogShell`.
- Si se necesita un ancho distinto, primero evaluar si uno de los valores de `AppDialogDimensions` ya cubre el caso.
- No hardcodear `maxWidth` nuevos sin justificar el caso y sin actualizar este documento.

## Estado de reutilizacion verificado
- Antes de este ajuste no existia un widget shell reusable de dialogo; solo habia implementaciones locales y helpers parciales.
- Desde este ajuste, el estandar reusable queda compuesto por `AppAlerts` + `AppDialogShell` + `AppDialogDimensions`.

## Modulos ya alineados
- `Massagens`
  - alta de atendimento
  - gestion de prestadores
- `Reservas`
  - alta de nueva reserva
- `Agenda`
  - actualizacion de reserva
  - cancelacion de reserva
  - dialogs propios migrados a `AppDialogShell`

## Criterio visual
- Dialogos mas compactos y equilibrados.
- Botones visibles sin ocupar demasiado ancho.
- Mensajes con jerarquia clara: icono, titulo, descripcion y accion.
- Consistencia de ancho entre modulos para que el usuario perciba una sola familia de modales.
