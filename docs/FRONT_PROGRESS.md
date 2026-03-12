# FRONT PROGRESS - QUEDRAS

## Estado general frontend
- Proyecto: QUEDRAS Frontend
- Estado: En progreso (Hito 5 backend completado, frontend N/A sin cambios funcionales)
- Ultimo hito trabajado: Hito 5 - API backend de reservas (sin implementacion frontend)
- Ultima actualizacion: 2026-03-12
- Fuente de verdad global: `C:/Users/Public/Documents/Proyectos/quadras/docs/TABLERO_PROGRESO.md`
- Proximo paso frontend: Iniciar Hito 6 con vistas de agenda y alta sobre la API definida en Hito 5.

## Hitos frontend
| Hito | Nombre | Estado frontend | Tests | Documentacion | Commit | Observaciones |
|------|--------|-----------------|-------|---------------|--------|---------------|
| 1 | Inicializacion y orden del proyecto | Completado | OK (`flutter test`) | Completada | Hecho (`7d60e05`, `ea8e76b`, `8ecd571`) | Documentacion base creada, test de smoke aprobado y cierre de hito confirmado. |
| 3 | Configuracion base frontend Flutter Desktop + estructura del cliente | Completado | OK (`flutter test`, `flutter analyze`) | Completada | Hecho (commit de cierre de Hito 3) | Shell desktop creado con rutas base y cliente HTTP desacoplado para red local. |
| 4 | Modelo de dominio de reservas | Completado | OK (`flutter test`, `flutter analyze`) | Completada | Hecho (commit de cierre de Hito 4 frontend) | Contrato `Reservation` y serializacion JSON alineados al backend. |
| 5 | API backend de reservas | N/A | OK (`flutter test`, `flutter analyze`) | Completada | Hecho documental (sin cambios de codigo frontend) | Hito de backend validado y sincronizado en seguimiento frontend. |
| 6 | Pantallas base de agenda y creacion de reserva | Pendiente | Pendiente | Pendiente | Pendiente | Primer flujo operativo de UI. |
| 7 | Validacion de solapamientos y reglas de negocio | Pendiente | Pendiente | Pendiente | Pendiente | Mensajeria y validaciones en UI. |
| 8 | Edicion y cancelacion de reservas | Pendiente | Pendiente | Pendiente | Pendiente | Mantenimiento de reservas desde cliente. |
| 9 | Conexion frontend-backend local | Pendiente | Pendiente | Pendiente | Pendiente | Integracion HTTP contra backend local. |
| 10 | Validacion integral, documentacion final y preparacion para instalacion | Pendiente | Pendiente | Pendiente | Pendiente | Cierre de version instalable. |

## Pendientes inmediatos frontend
- Iniciar Hito 6 para construir agenda y alta de reservas usando API local.
- Preparar alcance de Hito 6 (agenda y alta) sobre el contrato definido en Hito 4.
- Mantener alineacion de naming de entorno (`quedras`/`quadras`) para evitar confusion operativa.

## Bloqueos frontend
- Ninguno tecnico propio.
- Ninguna dependencia bloqueante activa.
