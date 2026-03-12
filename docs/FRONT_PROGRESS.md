# FRONT PROGRESS - QUEDRAS

## Estado general frontend
- Proyecto: QUEDRAS Frontend
- Estado: En progreso (sin bloqueos propios; depende del cierre de Hito 1 backend)
- Ultimo hito trabajado: Hito 1 - Inicializacion y orden del proyecto
- Ultima actualizacion: 2026-03-12
- Fuente de verdad global: `C:/Users/Public/Documents/Proyectos/quadras/docs/TABLERO_PROGRESO.md`
- Proximo paso frontend: Preparar base de arquitectura de cliente en Hito 3.

## Hitos frontend
| Hito | Nombre | Estado frontend | Tests | Documentacion | Commit | Observaciones |
|------|--------|-----------------|-------|---------------|--------|---------------|
| 1 | Inicializacion y orden del proyecto | Completado | OK (`flutter test`) | Completada | Hecho (`7d60e05`) | Documentacion base creada y test de smoke aprobado. |
| 3 | Configuracion base frontend Flutter Desktop + estructura del cliente | Pendiente | Pendiente | Pendiente | Pendiente | Estructura de app y organizacion por modulos. |
| 4 | Modelo de dominio de reservas | Pendiente | Pendiente | Pendiente | Pendiente | Modelos de datos y serializacion. |
| 6 | Pantallas base de agenda y creacion de reserva | Pendiente | Pendiente | Pendiente | Pendiente | Primer flujo operativo de UI. |
| 7 | Validacion de solapamientos y reglas de negocio | Pendiente | Pendiente | Pendiente | Pendiente | Mensajeria y validaciones en UI. |
| 8 | Edicion y cancelacion de reservas | Pendiente | Pendiente | Pendiente | Pendiente | Mantenimiento de reservas desde cliente. |
| 9 | Conexion frontend-backend local | Pendiente | Pendiente | Pendiente | Pendiente | Integracion HTTP contra backend local. |
| 10 | Validacion integral, documentacion final y preparacion para instalacion | Pendiente | Pendiente | Pendiente | Pendiente | Cierre de version instalable. |

## Pendientes inmediatos frontend
- Definir convencion interna de carpetas para capas UI/servicios/modelos en Hito 3.
- Alinear naming de app (`quedras` vs `quadras`) para evitar inconsistencias.
- Mantener sincronizacion con el desbloqueo backend de Hito 1 antes de iniciar integraciones.

## Bloqueos frontend
- Ninguno tecnico propio.
- Dependencia externa: Hito 1 global bloqueado por tests backend.
