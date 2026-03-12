# FRONT PROGRESS - QUEDRAS

## Estado general frontend
- Proyecto: QUEDRAS Frontend
- Estado: En progreso (Hito 6 completado en frontend)
- Ultimo hito trabajado: Hito 6 - Pantallas base de agenda y creacion de reserva
- Ultima actualizacion: 2026-03-12
- Fuente de verdad global: `C:/Users/Public/Documents/Proyectos/quadras/docs/TABLERO_PROGRESO.md`
- Proximo paso frontend: Avanzar a Hito 7 para validaciones de solapamiento y reglas de negocio.

## Hitos frontend
| Hito | Nombre | Estado frontend | Tests | Documentacion | Commit | Observaciones |
|------|--------|-----------------|-------|---------------|--------|---------------|
| 1 | Inicializacion y orden del proyecto | Completado | OK (`flutter test`) | Completada | Hecho (`7d60e05`, `ea8e76b`, `8ecd571`) | Documentacion base creada, test de smoke aprobado y cierre de hito confirmado. |
| 3 | Configuracion base frontend Flutter Desktop + estructura del cliente | Completado | OK (`flutter test`, `flutter analyze`) | Completada | Hecho (commit de cierre de Hito 3) | Shell desktop creado con rutas base y cliente HTTP desacoplado para red local. |
| 4 | Modelo de dominio de reservas | Completado | OK (`flutter test`, `flutter analyze`) | Completada | Hecho (commit de cierre de Hito 4 frontend) | Contrato `Reservation` y serializacion JSON alineados al backend. |
| 5 | API backend de reservas | N/A | OK (`flutter test`, `flutter analyze`) | Completada | Hecho documental (sin cambios de codigo frontend) | Hito de backend validado y sincronizado en seguimiento frontend. |
| 6 | Pantallas base de agenda y creacion de reserva | Completado | OK (`flutter test`, `flutter analyze`) | Completada | Hecho (commit de cierre de Hito 6 frontend) | Agenda diaria y formulario operativo con validaciones y estados locales. |
| 7 | Validacion de solapamientos y reglas de negocio | Pendiente | Pendiente | Pendiente | Pendiente | Mensajeria y validaciones en UI. |
| 8 | Edicion y cancelacion de reservas | Pendiente | Pendiente | Pendiente | Pendiente | Mantenimiento de reservas desde cliente. |
| 9 | Conexion frontend-backend local | Pendiente | Pendiente | Pendiente | Pendiente | Integracion HTTP contra backend local. |
| 10 | Validacion integral, documentacion final y preparacion para instalacion | Pendiente | Pendiente | Pendiente | Pendiente | Cierre de version instalable. |

## Pendientes inmediatos frontend
- Iniciar Hito 7 para mensajes y restricciones de solapamiento en UI.
- Coordinar reglas de conflicto con backend para mantener consistencia de validacion.
- Mantener alineacion de naming de entorno (`quedras`/`quadras`) para evitar confusion operativa.

## Bloqueos frontend
- Ninguno tecnico propio.
- Ninguna dependencia bloqueante activa.
