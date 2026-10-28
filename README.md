# COSTANORTE Frontend

Cliente Flutter Desktop para operacion interna de servicios del hotel.

## Configuracion soportada

Este proyecto no define ni consume variables de base de datos como `COSTANORTE_DB_*`, `QUADRAS_DB_*`, `DB_URL`, `DB_USERNAME` o `DB_PASSWORD`.

El frontend solo configura la URL HTTP del backend por:

- `COSTANORTE_API_BASE_URL`
- `QUEDRAS_API_BASE_URL` como compatibilidad temporal

## Alcance visible actual
- Login de acceso interno.
- `Agendamento de Massagens`
- `Aluguel de Quadras de Tenis`
- `Tours e Viagens`
- `Configuracoes`

Notas de alcance:
- La UI visible al operador sale en portugues de Brasil (`pt-BR`).
- `Quadras` concentra agenda diaria y nueva reserva dentro del mismo modulo.
- `Massagens` y `Tours e Viagens` quedaron preparados en frontend y pendientes de contrato backend dedicado.

## Ejecucion local
```powershell
flutter run -d windows --dart-define=COSTANORTE_API_BASE_URL=http://127.0.0.1:8080/api/v1
```

`127.0.0.1` solo es correcto cuando frontend y API se ejecutan en el mismo
equipo. Para una computadora cliente de la red local, indicar la IP o DNS del
equipo que ejecuta `quadras`:

```powershell
flutter run -d windows --dart-define=COSTANORTE_API_BASE_URL=http://192.168.1.50:8080/api/v1
```

El frontend consume solamente HTTP/JSON; no instala ni administra el backend o
la base de datos.

## Ejecucion web
Por defecto:
- en deploy web, consume el backend productivo `https://quadras-back-production.up.railway.app/api/v1`
- en desarrollo local con `flutter run -d chrome`, si detecta servidor Flutter en `localhost`, usa `http://127.0.0.1:8080/api/v1`

```powershell
flutter run -d chrome
```

Si el backend publicado vive en otro host o path, configurar la base URL explicitamente:

```powershell
flutter run -d chrome --dart-define=COSTANORTE_API_BASE_URL=https://mi-backend.ejemplo.com/api/v1
```

Si el backend local corre en otro puerto:

```powershell
flutter run -d chrome --dart-define=COSTANORTE_API_BASE_URL=http://127.0.0.1:8080/api/v1
```

## Validacion tecnica
```powershell
flutter test
flutter analyze
```

## Build de Windows
```powershell
flutter build windows --release --dart-define=COSTANORTE_API_BASE_URL=http://127.0.0.1:8080/api/v1
```

## Build Web
```powershell
flutter build web --release --base-href /costanorte/ --dart-define=COSTANORTE_API_BASE_URL=https://quadras-back-production.up.railway.app/api/v1
```

Si el backend web no comparte origen con el frontend:

```powershell
flutter build web --release --dart-define=COSTANORTE_API_BASE_URL=https://mi-backend.ejemplo.com/api/v1
```

Compatibilidad temporal:
- El cliente tambien acepta `QUEDRAS_API_BASE_URL` mientras se completa la migracion de entornos.

## Publicacion en Hostinger
- Backend configurado para el frontend publicado: `https://quadras-back-production.up.railway.app/api/v1`
- Generar build web:

```powershell
flutter build web --release --base-href /costanorte/ --dart-define=COSTANORTE_API_BASE_URL=https://quadras-back-production.up.railway.app/api/v1
```

- Subir a Hostinger todo el contenido de `build/web/` dentro de `public_html/`.
- El proyecto incluye `web/.htaccess` para que Flutter Web resuelva rutas SPA correctamente en Apache.
- Si el frontend se publica dentro de una subcarpeta, rebuild con `--base-href /subcarpeta/`.

Preflight de produccion web:
```powershell
.\scripts\frontend_preflight.ps1
```

Preflight para Windows local:
```powershell
.\scripts\frontend_preflight.ps1 -Target windows -ApiBaseUrl http://127.0.0.1:8080/api/v1
```

## Documentacion de soporte
- `docs/INSTALACION_FRONTEND_HOTEL.md`
- `docs/VALIDACION_FRONTEND_HITO12.md`
- `docs/VALIDACION_FRONTEND_HITO10.md`
- `docs/FRONT_PROGRESS.md`
- `docs/FRONT_CHANGELOG.md`
- `docs/FRONT_AGENT_GUIDELINES.md`
- `docs/INTERNAL_NAVIGATION_STANDARD.md`
- `docs/CALENDAR_LAYOUT_STANDARD.md`
- `docs/MASSAGES_PROVIDER_ADD_STANDARD.md`
- `docs/MASSAGES_SUMMARY_REPORT_PLAN.md`
- `docs/MASSAGES_PROVIDER_REPORT_PDF_STANDARD.md`
- `docs/SYSTEM_OPERATION_RULES.md`
- `docs/BACKEND_MASSAGES_ADJUSTMENT_PLAN.md`
