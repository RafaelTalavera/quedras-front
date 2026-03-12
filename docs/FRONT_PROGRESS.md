# FRONT PROGRESS - QUEDRAS

## Estado general frontend
- Proyecto: QUEDRAS Frontend
- Estado: En progreso (Hito 3 completado, pendiente Hito 4)
- Ultimo hito trabajado: Hito 3 - Configuracion base frontend Flutter Desktop + estructura del cliente
- Ultima actualizacion: 2026-03-12
- Fuente de verdad global: `C:/Users/Public/Documents/Proyectos/quadras/docs/TABLERO_PROGRESO.md`
- Proximo paso frontend: Iniciar Hito 4 con modelos de dominio de reservas y serializacion.

## Hitos frontend
| Hito | Nombre | Estado frontend | Tests | Documentacion | Commit | Observaciones |
|------|--------|-----------------|-------|---------------|--------|---------------|
| 1 | Inicializacion y orden del proyecto | Completado | OK (`flutter test`) | Completada | Hecho (`7d60e05`, `ea8e76b`, `8ecd571`) | Documentacion base creada, test de smoke aprobado y cierre de hito confirmado. |
| 3 | Configuracion base frontend Flutter Desktop + estructura del cliente | Completado | OK (`flutter test`, `flutter analyze`) | Completada | Hecho (commit de cierre de Hito 3) | Shell desktop creado con rutas base y cliente HTTP desacoplado para red local. |
| 4 | Modelo de dominio de reservas | Pendiente | Pendiente | Pendiente | Pendiente | Modelos de datos y serializacion. |
| 6 | Pantallas base de agenda y creacion de reserva | Pendiente | Pendiente | Pendiente | Pendiente | Primer flujo operativo de UI. |
| 7 | Validacion de solapamientos y reglas de negocio | Pendiente | Pendiente | Pendiente | Pendiente | Mensajeria y validaciones en UI. |
| 8 | Edicion y cancelacion de reservas | Pendiente | Pendiente | Pendiente | Pendiente | Mantenimiento de reservas desde cliente. |
| 9 | Conexion frontend-backend local | Pendiente | Pendiente | Pendiente | Pendiente | Integracion HTTP contra backend local. |
| 10 | Validacion integral, documentacion final y preparacion para instalacion | Pendiente | Pendiente | Pendiente | Pendiente | Cierre de version instalable. |

## Pendientes inmediatos frontend
- Iniciar modelos de dominio de reservas en cliente (Hito 4) alineados al backend.
- Definir contrato de serializacion para `Reserva` y estados asociados.
- Mantener alineacion de naming de entorno (`quedras`/`quadras`) para evitar confusion operativa.

## Bloqueos frontend
- Ninguno tecnico propio.
- Ninguna dependencia bloqueante activa.
