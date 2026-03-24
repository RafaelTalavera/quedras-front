# FRONT PROGRESS - COSTANORTE

## Estado general frontend
- Proyecto: COSTANORTE Frontend
- Estado: En progreso (snapshot operativo post Hito 12, con `Massagens` y `Quadras` ya en uso local)
- Ultimo hito trabajado: Post Hito 12 - consolidacion comercial, `Massagens` por prestador/masajista y operacion real de `Quadras`
- Ultima actualizacion: 2026-03-24
- Fuente de verdad global: `C:/Users/Public/Documents/Proyectos/quadras/docs/TABLERO_PROGRESO.md`
- Proximo paso frontend: pasar a una etapa de mejora sobre experiencia operativa, consistencia de mensajes y cierre de contratos backend pendientes.

## Snapshot actual de desarrollo
- Fecha de corte: 2026-03-24
- `Quadras` ya opera con backend autenticado real para listar reservas, lanzar reservas, informar pago, cancelar y administrar tarifas/materiales.
- Se validaron lanzamientos de prueba persistidos en base para `Hospede`, `Externo` y `VIP` el dia `2026-03-25`.
- `Massagens` ya opera con relacion `prestador -> masajista`, resumen por prestador y acciones operativas integradas en la pantalla principal.
- La autenticacion JWT sigue en memoria y protege modulos internos del sistema.
- El frente inmediato de mejora es endurecer validaciones y UX operacional, en especial mensajes al usuario, reglas de agenda y alineacion frontend-backend donde aun hay diferencias.

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

## Actualizacion post Hito 12
- Fecha: 2026-03-16
- Alcance visible reducido a 3 modulos funcionales (`Massagens`, `Quadras`, `Tours e Viagens`) mas `Configuracoes`.
- El shell mantiene el layout base, pero elimina el dashboard tecnico y cualquier texto de infraestructura visible al operador.
- `Quadras` unifica agenda y alta dentro del mismo modulo.
- Mensajes visibles y errores propagados a la UI normalizados a portugues de Brasil (`pt-BR`).
- Validaciones ejecutadas en esta fase: `flutter analyze`, `flutter test`.

## Actualizacion Massagens - Prestadores
- Fecha: 2026-03-24
- `Massagens` ya opera con relacion `prestador -> masajista`.
- El frontend permite administrar varios masajistas por prestador.
- El dialogo de `Prestadores` ahora soporta:
  - alta de prestador
  - edicion de prestador seleccionado
  - activacion/desactivacion de prestador
  - alta de masajista dentro del prestador
  - activacion/desactivacion de masajista
- El formulario de atencion usa `providerId` y `therapistId`.
- La validacion de conflicto horario se hace por masajista.
- Documento de detalle: `docs/MASSAGES_PROVIDERS_STATUS.md`.

## Actualizacion Massagens - Visualizacion de Resumen
- Fecha: 2026-03-24
- `Massagens` ya muestra en el sistema la visualizacion `Resumo por prestador`.
- El operador puede consultar un rango, ver la tabla de resumen y abrir el detalle de un prestador sin salir de la pantalla principal.
- La visualizacion convive con:
  - `Resumo do mes`
  - agenda mensual
  - panel `Dia selecionado`
- Documento de detalle: `docs/MASSAGES_SUMMARY_REPORT_PLAN.md`.

## Pendientes inmediatos frontend
- Cerrar y validar contrato backend especifico para `Massagens` con estructura real de `therapists`, `status`, edicion, cancelacion y auditoria por usuario.
- Definir contrato backend especifico para `Tours e Viagens`.
- Verificar en backend que JWT quede persistido como autor real en `createdBy/updatedBy/cancelledBy`.
- Evaluar si la sesion seguira solo en memoria o necesitara persistencia controlada.
- Alinear en backend la regla de `Quadras` para bloquear fechas pasadas, hoy resuelta solo en frontend.
- Continuar mejorando alertas y textos operativos para que el operador reciba feedback mas claro segun conflicto, validacion o error real.

## Bloqueos frontend
- Sin bloqueos tecnicos abiertos; pendiente definicion funcional de backend para los nuevos modulos comerciales.
