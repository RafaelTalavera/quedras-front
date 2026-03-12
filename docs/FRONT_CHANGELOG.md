# FRONT CHANGELOG - QUEDRAS

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
