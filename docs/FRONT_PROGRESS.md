# FRONT PROGRESS - COSTANORTE

## Estado general frontend
- Proyecto: COSTANORTE Frontend
- Estado: Completado (Hito 12 frontend)
- Ultimo hito trabajado: Hito 12 - Seguridad de usuarios con JWT y rol inicial
- Ultima actualizacion: 2026-03-14
- Fuente de verdad global: `C:/Users/Public/Documents/Proyectos/quadras/docs/TABLERO_PROGRESO.md`
- Proximo paso frontend: Preparar fase de multiples roles y politicas de autorizacion por pantalla cuando backend lo habilite.

## Hitos frontend
| Hito | Nombre | Estado frontend | Tests | Documentacion | Commit | Observaciones |
|------|--------|-----------------|-------|---------------|--------|---------------|
| 1 | Inicializacion y orden del proyecto | Completado | OK (`flutter test`) | Completada | Hecho (`7d60e05`, `ea8e76b`, `8ecd571`) | Documentacion base creada, test de smoke aprobado y cierre de hito confirmado. |
| 3 | Configuracion base frontend Flutter Desktop + estructura del cliente | Completado | OK (`flutter test`, `flutter analyze`) | Completada | Hecho (commit de cierre de Hito 3) | Shell desktop creado con rutas base y cliente HTTP desacoplado para red local. |
| 4 | Modelo de dominio de reservas | Completado | OK (`flutter test`, `flutter analyze`) | Completada | Hecho (commit de cierre de Hito 4 frontend) | Contrato `Reservation` y serializacion JSON alineados al backend. |
| 5 | API backend de reservas | N/A | OK (`flutter test`, `flutter analyze`) | Completada | Hecho documental (sin cambios de codigo frontend) | Hito de backend validado y sincronizado en seguimiento frontend. |
| 6 | Pantallas base de agenda y creacion de reserva | Completado | OK (`flutter test`, `flutter analyze`) | Completada | Hecho (commit de cierre de Hito 6 frontend) | Agenda diaria y formulario operativo con validaciones y estados locales. |
| 7 | Validacion de solapamientos y reglas de negocio | Completado | OK (`flutter test`, `flutter analyze`) | Completada | Hecho (commit de cierre de Hito 7 frontend) | Reglas de horario, duracion y solapamiento alineadas al backend con mensajes consistentes. |
| 8 | Edicion y cancelacion de reservas | Completado | OK (`flutter test`, `flutter analyze`) | Completada | Hecho (commit de cierre de Hito 8 frontend) | Agenda permite editar/cancelar reservas con reglas de estado y mensajes alineados al backend. |
| 9 | Conexion frontend-backend local | Completado | OK (`flutter test`, `flutter analyze`) | Completada | Hecho (commit de cierre de Hito 9 frontend) | Servicio de reservas conectado por HTTP local con manejo de errores de API y red. |
| 10 | Validacion integral, documentacion final y preparacion para instalacion | Completado | `flutter test` OK, `flutter analyze` OK, `flutter doctor -v` OK, `flutter build windows --release` OK | Completada | Hecho (`f3a5963` + commit de cierre actual) | Toolchain de Windows resuelto con Visual Studio Community y binario release generado en `build/windows/x64/runner/Release/`. |
| 11 | Renombre seguro de QUEDRAS a COSTANORTE (fase 1) | Completado | `flutter pub get` OK, `flutter test` OK, `flutter analyze` OK, `flutter build windows --release` OK | Completada | Hecho (commit frontend de Hito 11) | App renombrada a COSTANORTE con binario `costanorte.exe` y compatibilidad temporal con `QUEDRAS_API_BASE_URL`. |
| 12 | Seguridad de usuarios con JWT y rol inicial | Completado | OK (`flutter test`, `flutter analyze`, `flutter build windows --release`) | Completada | Hecho (commit de cierre Hito 12 frontend) | Login implementado con sesion JWT en memoria, logout, guard de rutas y envio de `Authorization: Bearer <token>` al backend. |

## Pendientes inmediatos frontend
- Planificar persistencia segura o renovacion controlada de sesion si el producto deja de ser solo local/operativo.
- Preparar ampliacion de roles y permisos por pantalla cuando backend exponga nuevos perfiles.
- Planificar fase 2 de renombre interno (paquetes/rutas de repositorio) cuando el cliente lo apruebe.

## Bloqueos frontend
- Sin bloqueos abiertos; Hito 12 frontend completado.
