# PLAN FRONTEND - AGENDA Y ALERTAS DE MANTENIMIENTO

Fecha: 2026-10-28  
Estado: `Propuesto para implementacion`  
Tipo: `Cross-repo`

Documento canonico de dominio, contratos, persistencia, fases y criterios de
aceptacion:

`C:/Users/Public/Documents/Proyectos/quadras/docs/MAINTENANCE_ALERTS_AND_CALENDAR_PLAN.md`

## Alcance Flutter

- incorporar agenda diaria, semanal y mensual de mantenimiento;
- reutilizar `lib/core/widgets/operational_timeline.dart` y los estandares
  visuales existentes;
- separar backlog de ordenes sin agenda;
- agregar campana global, contador no leido e historial de avisos;
- abrir la orden desde aviso interno, SSE o push;
- presentar `Reagendar` y `Cerrar exitosamente` como acciones principales;
- exigir notas de resolucion al cerrar exitosamente;
- mantener `Iniciar trabajo` en el detalle normal de la orden;
- registrar y revocar suscripciones push sin exponer secretos;
- soportar estados de permiso, canal no disponible, offline y token invalido;
- excluir Google Calendar y cualquier OAuth de Google.

## Definiciones funcionales confirmadas

- destinatarios: responsable autenticado asignado y operadores o supervisores
  autorizados;
- zona horaria: `America/Sao_Paulo`;
- descartar oculta el aviso actual, pero no resuelve la orden;
- el aviso de inicio no se repite; al vencer el fin aparece un aviso de atraso y
  puede repetirse cada 60 minutos dentro de la jornada;
- las notas de cierre son obligatorias;
- Windows cerrado mediante WNS/MSIX no bloquea la primera salida; web/PWA y
  Windows con la aplicacion abierta son la prioridad.

## Orden de trabajo

1. Modelos y contratos aditivos (`scheduleVersion`, notificaciones y
   suscripciones).
2. Agenda por rango con vistas diaria, semanal y mensual.
3. Formulario de reagendamiento con motivo y control de version.
4. Campana global y dialogo de resolucion.
5. Actualizacion por SSE y ciclo de vida de la aplicacion.
6. Push web/PWA y deep link a la orden.
7. Adaptadores y validacion especifica de plataformas restantes.

## Restricciones

- el frontend no calcula autoritativamente vencimientos;
- el push no cambia estados directamente;
- no almacenar credenciales privadas de proveedores push;
- no ocultar la campana si el usuario rechaza permisos;
- no hacer polling por fila ni cargar historico completo para la agenda;
- no declarar soporte en segundo plano sin prueba en la plataforma real.

## Validacion minima por entrega

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Las pruebas focalizadas deben cubrir agenda, campana, reagendamiento, cierre,
concurrencia, permisos, deep links y recuperacion cuando el push no llega.
