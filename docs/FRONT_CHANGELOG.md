# FRONT CHANGELOG - COSTANORTE

## 2026-03-26 | Post Hito 12 | Sidebar desktop de Massagens con navegacion interna por bloques
- Componente afectado: Frontend (`Shell` + `Massagens`) + documentacion UI
- Archivos tocados:
  - `lib/features/home/presentation/shell_page.dart`
  - `lib/features/massages/presentation/massage_booking_page.dart`
  - `docs/INTERNAL_NAVIGATION_STANDARD.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: extender a `Massagens` el mismo patron ya aplicado en `Quadras`, permitiendo acceso rapido desde el sidebar izquierdo a los bloques operativos principales de la pantalla.
- Impacto funcional:
  - `Massagens` ahora expone accesos directos a `Dia selecionado`, `Agenda mensal` y `Resumo do mes`
  - el sidebar contextual se sincroniza con el scroll de la pantalla
  - el shell preserva estado y posicion al navegar dentro del modulo sin recrear la vista

## 2026-03-26 | Post Hito 12 | Sidebar desktop de Quadras con navegacion interna y compactacion operativa
- Componente afectado: Frontend (`Shell` + `Quadras`) + documentacion UI
- Archivos tocados:
  - `lib/features/home/presentation/shell_page.dart`
  - `lib/features/tennis/presentation/tennis_rental_page.dart`
  - `docs/INTERNAL_NAVIGATION_STANDARD.md`
  - `docs/SIDEBAR_LAYOUT_STANDARD.md`
  - `docs/FRONT_AGENT_GUIDELINES.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: agregar acceso interno desde el sidebar izquierdo a los bloques de `Quadras`, corregir desbordes verticales del panel y cerrar una version mas compacta del bloque institucional y de sesion.
- Impacto funcional:
  - `Quadras` ahora expone accesos directos a `Dia selecionado`, `Agenda mensal` y `Resumo do periodo`
  - el shell conserva estado y scroll de la pantalla usando navegacion interna sin recrear la seccion
  - el sidebar desktop elimina textos institucionales redundantes bajo el logo
  - `Sessao ativa` queda en una version visual mucho mas compacta para liberar altura util
  - el criterio de layout del sidebar queda documentado para futuras iteraciones

## 2026-03-26 | Post Hito 12 | Selector directo de fecha en el detalle diario de Quadras
- Componente afectado: Frontend (`Quadras`) + documentacion funcional
- Archivos tocados:
  - `lib/features/tennis/presentation/tennis_rental_page.dart`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Permitir que el operador cambie la fecha directamente desde la tarjeta `Dia selecionado`, sin depender solo del calendario mensual para consultar reservas de otro dia.
- Impacto funcional: La tarjeta diaria ahora incluye `Alterar dia`, abre selector de fecha y mantiene sincronizada la agenda; si el operador cambia a otro mes, tambien se refresca el resumen mensual asociado.

## 2026-03-26 | Post Hito 12 | Quadras con catalogo persistido y gestion operativa de profesores parceros
- Componente afectado: Frontend (`Quadras`) + integracion compartida con backend
- Archivos tocados:
  - `lib/features/tennis/presentation/tennis_rental_page.dart`
  - `lib/features/courts/application/court_app_service.dart`
  - `lib/features/courts/domain/court_models.dart`
  - `lib/features/courts/infrastructure/http_court_app_service.dart`
  - `lib/core/localization/pt_br_error_translator.dart`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: cerrar el flujo cross-repo para que `Professor parceiro` no dependa de nombres hardcodeados y pueda administrarse desde el panel operativo.
- Impacto funcional:
  - `Nova reserva de quadra` ahora carga profesores parceros desde backend y solo permite seleccionar nombres activos del catalogo
  - el formulario prioriza `Tipo de usuario` y adapta `Nombre` a selector cerrado cuando aplica
  - el dialogo `Tarifas, materiais e parceiros` ya permite listar, buscar, crear, editar y activar/inactivar profesores parceros
  - los errores de validacion de backend para partner coaches se traducen en UI

## 2026-03-25 | Post Hito 12 | Estandar documentado para navegacion interna sin remonte de secciones
- Componente afectado: Frontend (`Shell`) + documentacion tecnica
- Archivos tocados:
  - `lib/features/home/presentation/shell_page.dart`
  - `docs/INTERNAL_NAVIGATION_STANDARD.md`
  - `README.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Dejar documentado el patron correcto para cambiar entre secciones internas sin recrear rutas ni pantallas pesadas, evitando la micro-latencia visible al operador.
- Impacto funcional: El shell conserva las pantallas internas con `IndexedStack`, evita relanzar `initState` y fetch al pasar entre modulos y deja una regla explicita para futuras implementaciones.

## 2026-03-24 | Post Hito 12 | Quadras alineado al estandar de calendario y mejora del selector horario
- Componente afectado: Frontend (`Quadras`) + documentacion UI
- Archivos tocados:
  - `lib/features/tennis/presentation/tennis_rental_page.dart`
  - `docs/CALENDAR_LAYOUT_STANDARD.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Corregir el desvio visual de `Quadras` respecto al calendario aprobado en `Massagens` y simplificar la reserva de horario con una UX mas operativa.
- Impacto funcional: `Quadras` ahora usa agenda mensual compacta con el mismo patron interno de `Massagens`, el selector de mes queda unificado dentro del card y el formulario de reserva propone `Fin = Inicio + 1 hora` con opcion de extender manualmente el horario final.

## 2026-03-24 | Post Hito 12 | Corte documental de desarrollo y siguiente etapa de mejora
- Componente afectado: Frontend (documentacion transversal + `Quadras`)
- Archivos tocados:
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
  - `lib/core/localization/pt_br_error_translator.dart`
  - `lib/features/tennis/presentation/tennis_rental_page.dart`
- Motivo del cambio: Dejar registrado el punto actual del desarrollo antes de pasar a una etapa de mejora, incluyendo el estado operativo de `Quadras` y el ultimo ajuste de alertas/validaciones visibles para el operador.
- Impacto funcional: `Quadras` ahora bloquea fechas pasadas desde la UI, convierte el conflicto de horario ocupado en alerta de warning mas clara y mantiene documentado que el siguiente paso es endurecer UX y reglas compartidas con backend.

## 2026-03-24 | Post Hito 12 | Visualizacion de resumen por prestador ya disponible en Massagens
- Componente afectado: Frontend (`Massagens`) + documentacion funcional
- Archivos tocados:
  - `lib/features/massages/application/massage_app_service.dart`
  - `lib/features/massages/domain/massage_models.dart`
  - `lib/features/massages/infrastructure/http_massage_app_service.dart`
  - `lib/features/massages/presentation/massage_booking_page.dart`
  - `test/features/massages/infrastructure/http_massage_app_service_test.dart`
  - `test/features/massages/presentation/massage_booking_page_test.dart`
  - `docs/MASSAGES_SUMMARY_REPORT_PLAN.md`
  - `docs/MASSAGES_PROVIDERS_STATUS.md`
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Completar la visualizacion aprobada para consultar resumen de atenciones y cobros por prestador, y dejar documentado que ya forma parte del sistema.
- Impacto funcional: El operador ya puede ver la tabla `Resumo por prestador`, filtrar por rango y seleccionar un prestador para abrir su detalle dentro de `Massagens`, sin perder la agenda principal.

## 2026-03-24 | Post Hito 12 | Plan documentado para resumen por prestador en Massagens
- Componente afectado: Frontend (documentacion funcional compartida con backend)
- Archivos tocados:
  - `docs/MASSAGES_SUMMARY_REPORT_PLAN.md`
  - `docs/FRONT_PROGRESS.md`
  - `README.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Dejar especificado el siguiente paquete funcional de `Massagens` para soportar tabla de resumen por prestador y detalle navegable, alineando alcance frontend y contrato backend esperado.
- Impacto funcional: Sin cambios de UI o API en esta pasada; queda definido el plan de implementacion, el contrato recomendado y el criterio de cierre para ejecutar el desarrollo real en ambos repositorios.

## 2026-03-23 | Post Hito 12 | Informar pago rapido en Massagens
- Componente afectado: Frontend (`Massagens`)
- Archivos tocados:
  - `lib/features/massages/presentation/massage_booking_page.dart`
  - `test/features/massages/presentation/massage_booking_page_test.dart`
  - `test/features/massages/infrastructure/http_massage_app_service_test.dart`
  - `docs/BACKEND_MASSAGES_ADJUSTMENT_PLAN.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Exponer en UI el endpoint ya existente de actualizacion rapida de pago y corregir el falso estado vacio del selector cuando el dia tenia atendimientos no elegibles.
- Impacto funcional: El operador puede informar pago desde la barra superior y desde las acciones del booking. El selector ahora lista todos los atendimientos del dia, distingue los que estan pagos o cancelados y solo habilita la accion para los elegibles.

## 2026-03-20 | Post Hito 12 | Regla transversal de no eliminacion y auditoria operativa
- Componente afectado: Frontend (documentacion de sistema + Massagens)
- Archivos tocados:
  - `docs/SYSTEM_OPERATION_RULES.md`
  - `docs/BACKEND_MASSAGES_ADJUSTMENT_PLAN.md`
  - `README.md`
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Dejar explicita la regla general de negocio por la cual los registros operativos no se eliminan, sino que se cancelan o inactivan con justificacion y trazabilidad de usuario.
- Impacto funcional: El repositorio queda documentado para exigir cancelacion con observacion y auditoria por usuario como criterio transversal de implementacion.

## 2026-03-20 | Post Hito 12 | Edicion y cancelacion de atendimientos de Massagens en frontend
- Componente afectado: Frontend (`Massagens`)
- Archivos tocados:
  - `lib/features/massages/application/massage_app_service.dart`
  - `lib/features/massages/domain/massage_models.dart`
  - `lib/features/massages/infrastructure/http_massage_app_service.dart`
  - `lib/features/massages/presentation/massage_booking_page.dart`
  - `lib/core/localization/pt_br_error_translator.dart`
  - `test/features/massages/presentation/massage_booking_page_test.dart`
  - `test/features/massages/infrastructure/http_massage_app_service_test.dart`
- Motivo del cambio: Preparar el frontend para mantener atendimientos sin borrar registros, habilitando edicion, cancelacion con observacion y visualizacion de estado.
- Impacto funcional: El operador puede cancelar o editar atendimientos desde el resumen diario y desde el calendario, mientras el frontend queda listo para consumir auditoria y estado reales del backend.

## 2026-03-20 | Post Hito 12 | Estandar reusable de dialogos y avisos
- Componente afectado: Frontend (`feedback`, `core/widgets`, documentacion UI)
- Archivos tocados:
  - `docs/DIALOG_ALERT_STANDARD.md`
  - `lib/core/widgets/app_dialog_shell.dart`
  - `lib/features/massages/presentation/massage_booking_page.dart`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Formalizar el estandar de avisos/dialogos para el usuario y consolidarlo en un shell reusable para dialogs propios.
- Impacto funcional: El proyecto queda con un criterio documentado y componentes base reutilizables para mantener dialogs compactos, consistentes y faciles de extender.

## 2026-03-20 | Post Hito 12 | Libreria de alertas tipo SweetAlert2
- Componente afectado: Frontend (`feedback`, `Massagens`, `Reservas`, `Agenda`)
- Archivos tocados:
  - `pubspec.yaml`
  - `pubspec.lock`
  - `lib/core/feedback/app_alerts.dart`
  - `lib/features/massages/presentation/massage_booking_page.dart`
  - `lib/features/reservations/presentation/new_reservation_page.dart`
  - `lib/features/schedule/presentation/schedule_page.dart`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Unificar avisos de exito, error, warning e informacion con una experiencia visual mas cercana a SweetAlert2 y desacoplarla del paquete concreto mediante un wrapper propio.
- Impacto funcional: Las operaciones de guardado y actualizacion ahora muestran alertas modales consistentes para el usuario, reutilizables desde cualquier modulo del front.

## 2026-03-20 | Post Hito 12 | Persistencia real del CRUD de Massagens
- Componente afectado: Frontend (`Massagens`)
- Archivos tocados:
  - `lib/features/massages/presentation/massage_booking_page.dart`
  - `test/features/massages/presentation/massage_booking_page_test.dart`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Corregir el bug por el cual `Lancar atendimento` y el alta/activacion de prestadores solo actualizaban el estado local del widget y no llamaban al backend autenticado.
- Impacto funcional: Los atendimientos y prestadores ahora usan el servicio HTTP real, envian payloads compatibles con backend y reflejan en UI el registro devuelto por API en lugar de datos inventados localmente.

## 2026-03-20 | Post Hito 12 | Desacople de fecha en Lancar atendimento de Massagens
- Componente afectado: Frontend (`Massagens`)
- Archivos tocados:
  - `lib/features/massages/presentation/massage_booking_page.dart`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Permitir que la fecha del formulario `Lancar atendimento` se edite dentro de la misma ventana sin depender de la fecha seleccionada en la agenda principal.
- Impacto funcional: El operador puede abrir el dialogo, cambiar la fecha del atendimento desde el propio formulario y guardar sin que la agenda mensual o el detalle del dia cambien automaticamente al nuevo dia.

## 2026-03-12 | Hito 1 | Inicializacion y orden del proyecto
- Componente afectado: Frontend (gestion documental y control de avance)
- Archivos tocados:
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Crear seguimiento especifico del frontend y sincronizarlo con tablero global.
- Impacto funcional: Sin cambios funcionales en la UI ni en logica de aplicacion.

## 2026-03-12 | Hito 1 | Inicializacion de control de versiones
- Componente afectado: Frontend (infraestructura de desarrollo)
- Archivos tocados:
  - `.git/` (repositorio inicializado)
- Motivo del cambio: Habilitar commits por hito segun metodologia solicitada.
- Impacto funcional: Sin impacto funcional en ejecucion de frontend.

## 2026-03-12 | Hito 1 | Validacion de frontend (smoke tests)
- Componente afectado: Frontend (calidad y validacion tecnica)
- Archivos tocados:
  - `test/widget_test.dart` (ejecutado sin cambios)
- Motivo del cambio: Ejecutar `flutter test` para validar estabilidad base.
- Impacto funcional: Sin cambios funcionales; test de smoke aprobado.

## 2026-03-12 | Hito 1 | Commit frontend de inicializacion
- Componente afectado: Frontend (codigo base + documentacion)
- Archivos tocados:
  - Estructura base Flutter Desktop (`lib/`, `test/`, `windows/`, `pubspec*`)
  - Documentacion de seguimiento en `docs/`
- Motivo del cambio: Registrar baseline frontend y seguimiento operativo en control de versiones.
- Impacto funcional: Sin cambios funcionales nuevos.

## 2026-03-12 | Hito 1 | Revalidacion de frontend y cierre documental
- Componente afectado: Frontend (calidad + documentacion)
- Archivos tocados:
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Revalidar `flutter test` y confirmar cierre de frontend para Hito 1.
- Impacto funcional: Sin cambios funcionales en UI.

## 2026-03-12 | Hito 2 | Revalidacion de frontend durante avance backend
- Componente afectado: Frontend (calidad y seguimiento)
- Archivos tocados:
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Ejecutar `flutter test` y mantener trazabilidad de que Hito 2 no introduce cambios funcionales en cliente.
- Impacto funcional: Sin cambios funcionales en UI.

## 2026-03-12 | Hito 2 | Sincronizacion por bloqueo de backend
- Componente afectado: Frontend (seguimiento)
- Archivos tocados:
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Reflejar que el cierre del Hito 2 depende de resolver credenciales MySQL en backend.
- Impacto funcional: Sin cambios funcionales en UI.

## 2026-03-12 | Hito 2 | Sincronizacion tras desbloqueo de backend
- Componente afectado: Frontend (seguimiento)
- Archivos tocados:
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Reflejar cierre tecnico de Hito 2 backend y habilitar inicio de Hito 3 frontend.
- Impacto funcional: Sin cambios funcionales en UI.

## 2026-03-12 | Hito 3 | Configuracion base de shell desktop y arquitectura cliente
- Componente afectado: Frontend (aplicacion Flutter Desktop)
- Archivos tocados:
  - `lib/main.dart`
  - `lib/app/**`
  - `lib/core/**`
  - `lib/features/**`
  - `test/widget_test.dart`
- Motivo del cambio: Reemplazar app de contador por shell operativa con rutas base y cliente HTTP desacoplado para backend local.
- Impacto funcional: Se habilita estructura base de cliente para agenda y reservas sin implementar aun logica de negocio.

## 2026-03-12 | Hito 3 | Validacion tecnica de frontend base
- Componente afectado: Frontend (calidad)
- Archivos tocados:
  - `test/widget_test.dart`
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Validar estabilidad de la nueva estructura con `flutter test` y `flutter analyze`, y dejar trazabilidad documental.
- Impacto funcional: Frontend base queda estable para iniciar Hito 4.

## 2026-03-12 | Hito 4 | Modelos de reserva y contrato de serializacion
- Componente afectado: Frontend (dominio de reservas)
- Archivos tocados:
  - `lib/features/reservations/domain/reservation_status.dart`
  - `lib/features/reservations/domain/reservation_model.dart`
  - `lib/features/reservations/domain/create_reservation_model.dart`
  - `lib/features/reservations/presentation/new_reservation_page.dart`
- Motivo del cambio: Definir contrato de datos del cliente alineado con backend para preparar los siguientes hitos.
- Impacto funcional: La UI mantiene comportamiento actual; se agregan estructuras de dominio reutilizables para API y vistas.

## 2026-03-12 | Hito 4 | Pruebas de serializacion y cierre documental frontend
- Componente afectado: Frontend (calidad + seguimiento)
- Archivos tocados:
  - `test/features/reservations/domain/reservation_models_test.dart`
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Validar `fromJson/toJson` de reservas y registrar cierre de frontend del Hito 4.
- Impacto funcional: Contrato frontend validado en `flutter test` y `flutter analyze`.

## 2026-03-12 | Hito 5 | Sincronizacion frontend de hito backend (N/A funcional)
- Componente afectado: Frontend (seguimiento + calidad)
- Archivos tocados:
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Registrar que Hito 5 se implementa en backend, revalidando frontend sin cambios funcionales.
- Impacto funcional: Sin cambios en UI; cliente listo para iniciar Hito 6 con API disponible.

## 2026-03-12 | Hito 6 | Pantalla base de agenda diaria
- Componente afectado: Frontend (feature schedule)
- Archivos tocados:
  - `lib/features/schedule/presentation/schedule_page.dart`
  - `lib/features/reservations/application/reservation_app_service.dart`
  - `lib/features/home/presentation/shell_page.dart`
  - `lib/app/router/app_router.dart`
  - `lib/app/quedras_app.dart`
- Motivo del cambio: Implementar agenda diaria operativa con carga, error, estado vacio y refresco por fecha.
- Impacto funcional: La app permite visualizar reservas del dia con estados locales y recarga manual.

## 2026-03-12 | Hito 6 | Formulario base de nueva reserva
- Componente afectado: Frontend (feature reservations)
- Archivos tocados:
  - `lib/features/reservations/presentation/new_reservation_page.dart`
  - `lib/features/reservations/application/reservation_app_service.dart`
  - `test/features/reservations/application/reservation_app_service_test.dart`
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Crear formulario de alta con validaciones locales y persistencia en memoria para flujo operativo inicial.
- Impacto funcional: Se habilita alta de reservas en cliente con mensajes de exito/error, listo para evolucionar reglas en Hito 7.

## 2026-03-12 | Hito 7 | Reglas de solapamiento y negocio en cliente
- Componente afectado: Frontend (servicio de reservas + formulario de alta)
- Archivos tocados:
  - `lib/features/reservations/application/reservation_app_service.dart`
  - `lib/features/reservations/presentation/new_reservation_page.dart`
  - `test/features/reservations/application/reservation_app_service_test.dart`
- Motivo del cambio: Alinear el cliente con las reglas de backend para horario operativo, duraciones permitidas y rechazo de solapamientos.
- Impacto funcional: La UI y el servicio en memoria bloquean reservas invalidas y muestran mensajes consistentes con API.

## 2026-03-12 | Hito 7 | Validacion tecnica y cierre documental frontend
- Componente afectado: Frontend (calidad + seguimiento)
- Archivos tocados:
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Ejecutar `flutter test` y `flutter analyze` en verde y consolidar cierre del Hito 7 en el seguimiento frontend.
- Impacto funcional: Frontend validado y listo para iniciar Hito 8 sin cambios fuera del alcance del hito.

## 2026-03-12 | Hito 8 | Edicion y cancelacion de reservas en agenda
- Componente afectado: Frontend (feature schedule + servicio de reservas)
- Archivos tocados:
  - `lib/features/schedule/presentation/schedule_page.dart`
  - `lib/features/reservations/application/reservation_app_service.dart`
  - `lib/features/reservations/domain/update_reservation_model.dart`
  - `test/features/reservations/application/reservation_app_service_test.dart`
- Motivo del cambio: Habilitar mantenimiento operativo de reservas desde la agenda mediante acciones de editar y cancelar.
- Impacto funcional: La UI permite actualizar datos de turnos y cancelarlos con controles de estado, manteniendo reglas de solapamiento/horario/duracion.

## 2026-03-12 | Hito 8 | Validacion tecnica y cierre documental frontend
- Componente afectado: Frontend (calidad + seguimiento)
- Archivos tocados:
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Ejecutar `flutter test` y `flutter analyze` en verde y registrar cierre del Hito 8 en seguimiento frontend.
- Impacto funcional: Frontend estable para iniciar Hito 9 de integracion local con backend.

## 2026-03-12 | Hito 9 | Integracion HTTP local del modulo de reservas
- Componente afectado: Frontend (red + aplicacion de reservas)
- Archivos tocados:
  - `lib/core/network/api_client.dart`
  - `lib/core/network/local_http_client.dart`
  - `lib/features/reservations/infrastructure/http_reservation_app_service.dart`
  - `lib/app/quedras_app.dart`
  - `lib/features/dashboard/presentation/dashboard_page.dart`
  - `lib/features/reservations/presentation/new_reservation_page.dart`
- Motivo del cambio: Reemplazar el servicio en memoria por adaptador HTTP local y completar operaciones `list/create/update/cancel` contra API backend.
- Impacto funcional: El frontend opera con datos persistidos del backend local y maneja errores de conectividad/red en mensajes controlados.

## 2026-03-12 | Hito 9 | Pruebas de integracion del cliente y cierre documental
- Componente afectado: Frontend (calidad + seguimiento)
- Archivos tocados:
  - `test/features/reservations/infrastructure/http_reservation_app_service_test.dart`
  - `test/widget_test.dart`
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Validar adaptador HTTP de reservas, actualizar dobles de `ApiClient` y consolidar cierre documental del Hito 9.
- Impacto funcional: `flutter test` y `flutter analyze` en verde con cobertura de escenarios de exito y error en integracion local.

## 2026-03-12 | Hito 10 | Preparacion de instalacion y preflight frontend
- Componente afectado: Frontend (documentacion + scripts operativos)
- Archivos tocados:
  - `README.md`
  - `docs/INSTALACION_FRONTEND_HOTEL.md`
  - `docs/VALIDACION_FRONTEND_HITO10.md`
  - `scripts/frontend_preflight.ps1`
- Motivo del cambio: Consolidar guia de instalacion/ejecucion del cliente y script de preflight para validar entorno de despliegue.
- Impacto funcional: Sin cambios en logica de UI; mejora la capacidad de instalacion y soporte operativo.

## 2026-03-12 | Hito 10 | Validacion tecnica y deteccion de bloqueo de build
- Componente afectado: Frontend (calidad + gobernanza)
- Archivos tocados:
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
  - `docs/VALIDACION_FRONTEND_HITO10.md`
- Motivo del cambio: Ejecutar `flutter test`, `flutter analyze`, `flutter build windows --release` y documentar bloqueo real por toolchain Visual Studio incompleto.
- Impacto funcional: Flujo funcional validado en desarrollo; build instalable Windows bloqueado hasta completar instalacion de Visual Studio.

## 2026-03-12 | Hito 10 | Resolucion de toolchain y cierre de build Windows
- Componente afectado: Frontend (instalacion + validacion final)
- Archivos tocados:
  - `docs/INSTALACION_FRONTEND_HOTEL.md`
  - `docs/FRONT_PROGRESS.md`
  - `docs/VALIDACION_FRONTEND_HITO10.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Resolver prerequisitos de Visual Studio para Flutter Desktop y confirmar build release de Windows sin bloqueos.
- Impacto funcional: Frontend queda cerrando Hito 10 con `flutter test`, `flutter analyze`, `flutter doctor -v` y `flutter build windows --release` en OK.

## 2026-03-14 | Hito 11 | Renombre seguro de frontend a COSTANORTE (fase 1)
- Componente afectado: Frontend (branding + configuracion + build)
- Archivos tocados:
  - `pubspec.yaml`
  - `lib/main.dart`
  - `lib/app/costanorte_app.dart` (renombrado desde `lib/app/quedras_app.dart`)
  - `lib/core/config/backend_config.dart`
  - `lib/features/home/presentation/shell_page.dart`
  - `lib/features/dashboard/presentation/dashboard_page.dart`
  - `windows/CMakeLists.txt`
  - `windows/runner/main.cpp`
  - `windows/runner/Runner.rc`
  - `scripts/frontend_preflight.ps1`
  - `test/**`
  - `README.md`
  - `docs/INSTALACION_FRONTEND_HOTEL.md`
  - `docs/VALIDACION_FRONTEND_HITO10.md`
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
- Motivo del cambio: Migrar nombre comercial de QUEDRAS a COSTANORTE sin romper entornos actuales, manteniendo fallback de `QUEDRAS_API_BASE_URL`.
- Impacto funcional: App desktop y ejecutable Windows pasan a `CostaNorte` / `costanorte.exe` con pruebas y build release en verde.

## 2026-03-14 | Hito 12 | Login JWT, guard de rutas y sesion operativa
- Componente afectado: Frontend (autenticacion + red + shell principal)
- Archivos tocados:
  - `lib/app/costanorte_app.dart`
  - `lib/app/router/app_router.dart`
  - `lib/app/router/app_routes.dart`
  - `lib/core/network/authorized_api_client.dart`
  - `lib/features/auth/**`
  - `lib/features/home/presentation/shell_page.dart`
  - `lib/features/dashboard/presentation/dashboard_page.dart`
  - `test/widget_test.dart`
  - `test/core/network/authorized_api_client_test.dart`
  - `test/features/auth/infrastructure/http_auth_app_service_test.dart`
- Motivo del cambio: Integrar autenticacion real contra backend local con `POST /api/v1/auth/login`, sesion JWT en memoria, logout y consumo autenticado del modulo de reservas.
- Impacto funcional: La app inicia en login, protege rutas internas, adjunta `Authorization: Bearer <token>` a llamadas autenticadas y redirige al login si la sesion queda invalida.

## 2026-03-14 | Hito 12 | Validacion tecnica y cierre documental frontend
- Componente afectado: Frontend (calidad + documentacion operativa)
- Archivos tocados:
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
  - `docs/INSTALACION_FRONTEND_HOTEL.md`
  - `docs/VALIDACION_FRONTEND_HITO12.md`
- Motivo del cambio: Ejecutar `flutter test`, `flutter analyze` y `flutter build windows --release`, y documentar el usuario demo con el flujo operativo del Hito 12.
- Impacto funcional: Frontend del Hito 12 queda validado, documentado y listo para uso local con backend JWT activo.

## 2026-03-16 | Post Hito 12 | Reenfoque comercial del frontend y normalizacion pt-BR
- Componente afectado: Frontend (shell principal + copy + modulos visibles + pruebas)
- Archivos tocados:
  - `lib/app/costanorte_app.dart`
  - `lib/app/router/app_router.dart`
  - `lib/app/router/app_routes.dart`
  - `lib/core/localization/pt_br_error_translator.dart`
  - `lib/features/auth/**`
  - `lib/features/home/presentation/shell_page.dart`
  - `lib/features/massages/**`
  - `lib/features/settings/**`
  - `lib/features/tennis/**`
  - `lib/features/tours/**`
  - `lib/features/reservations/**`
  - `lib/features/schedule/presentation/schedule_page.dart`
  - `test/**`
- Motivo del cambio: Reducir la experiencia visible a tres modulos de negocio (`Massagens`, `Quadras`, `Tours e Viagens`) mas `Configuracoes`, mantener el layout actual y eliminar contenido tecnico expuesto al operador.
- Impacto funcional: La app inicia en login, navega por modulos comerciales, concentra el flujo real de reservas dentro de `Quadras` y muestra mensajes visibles en portugues de Brasil.

## 2026-03-16 | Post Hito 12 | Actualizacion documental y validacion tecnica
- Componente afectado: Frontend (documentacion + trazabilidad)
- Archivos tocados:
  - `README.md`
  - `docs/FRONT_PROGRESS.md`
  - `docs/FRONT_CHANGELOG.md`
  - `docs/INSTALACION_FRONTEND_HOTEL.md`
  - `docs/VALIDACION_FRONTEND_HITO12.md`
- Motivo del cambio: Registrar el nuevo alcance comercial del cliente y dejar evidencia de validacion con `flutter analyze` y `flutter test`.
- Impacto funcional: Documentacion alineada a la UI vigente, al idioma pt-BR y al siguiente paso pendiente de integracion backend para masajes y tours.
## 2026-03-19 | Post Hito 12 | Correccion responsive de Massagens y estandar anti-overflow
- Componente afectado: Frontend (`Massagens` + documentacion UI)
- Archivos tocados:
  - `lib/features/massages/presentation/massage_booking_page.dart`
  - `docs/RESPONSIVE_LAYOUT_STANDARD.md`
- Motivo del cambio: Corregir overflow en el calendario mensual de massagens y dejar un estandar reusable para grids/cards responsive.
- Impacto funcional: La agenda de massagens adapta columnas y altura de celda segun el ancho disponible, reduciendo riesgo de desbordes en ventanas angostas.

## 2026-03-24 | Post Hito 12 | Prestadores con masajistas y edicion jerarquica
- Componente afectado: Frontend (`Massagens` dominio + servicio + UI + tests + documentacion)
- Archivos tocados:
  - `lib/features/massages/domain/massage_models.dart`
  - `lib/features/massages/application/massage_app_service.dart`
  - `lib/features/massages/infrastructure/http_massage_app_service.dart`
  - `lib/features/massages/presentation/massage_booking_page.dart`
  - `test/features/massages/infrastructure/http_massage_app_service_test.dart`
  - `test/features/massages/presentation/massage_booking_page_test.dart`
  - `docs/MASSAGES_PROVIDERS_STATUS.md`
- Motivo del cambio: Separar proveedor comercial de masajista operativo, permitir multiples masajistas por prestador y habilitar administracion del prestador seleccionado.
- Impacto funcional: El operador ahora selecciona `prestador -> masajista` al cargar atenciones, puede activar/desactivar masajistas, agregar masajistas dentro de un prestador y editar datos del prestador sin salir del dialogo.

## 2026-03-24 | Post Hito 12 | Estandar de alta y filtro para prestadores de massagens
- Componente afectado: Frontend (`Massagens` UI + documentacion operativa)
- Archivos tocados:
  - `lib/features/massages/presentation/massage_booking_page.dart`
  - `docs/MASSAGES_PROVIDER_ADD_STANDARD.md`
  - `docs/MASSAGES_PROVIDERS_STATUS.md`
  - `docs/FRONT_CHANGELOG.md`
  - `README.md`
- Motivo del cambio: Alinear el dialogo de prestadores a un flujo sin preseleccion, con resumen previo, tarjetas compactas, filtro por nombre y leyenda visual explicita para activacion.
- Impacto funcional: El operador ahora entra al dialogo en estado neutro, puede encontrar prestadores por coincidencia parcial de nombre y ve el estado `ON/OFF` del prestador de forma textual y consistente; el patron queda documentado para futuras implementaciones del proyecto.
