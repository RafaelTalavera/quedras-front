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
