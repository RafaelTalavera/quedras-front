# INSTALACION FRONTEND - COSTANORTE

## Objetivo
Instalar y ejecutar el frontend COSTANORTE en Windows o Web conectado al backend configurado del hotel.

## Prerequisitos
- Windows 10/11.
- Flutter SDK estable instalado.
- Visual Studio 2022 con workload `Desktop development with C++` (incluyendo MSVC, CMake tools y Windows SDK).
- `flutter doctor -v` sin errores bloqueantes para desktop Windows.
- Backend COSTANORTE operativo y accesible desde el entorno donde corre el frontend.

## Variables soportadas por el frontend

El frontend no lee variables de base de datos del backend.

No usa:

- `COSTANORTE_DB_*`
- `QUADRAS_DB_*`
- `DB_URL`
- `DB_USERNAME`
- `DB_PASSWORD`

Solo usa:

- `COSTANORTE_API_BASE_URL`
- `QUEDRAS_API_BASE_URL` como compatibilidad temporal

## Validacion del entorno Flutter
```powershell
flutter doctor -v
```

## Ejecucion en desarrollo (con backend local)
```powershell
flutter run -d windows --dart-define=COSTANORTE_API_BASE_URL=http://127.0.0.1:8080/api/v1
```

## Ejecucion web
Caso recomendado para despliegue publicado:
- frontend publicado consumiendo el backend productivo de Railway
- backend expuesto en `https://quadras-back-production-4973.up.railway.app/api/v1`

```powershell
flutter run -d chrome
```

Si el backend publicado vive en otro host o path:

```powershell
flutter run -d chrome --dart-define=COSTANORTE_API_BASE_URL=https://mi-backend.ejemplo.com/api/v1
```

## Acceso de prueba para QA/local
- Usuario: `operador.demo`
- Clave: `Costanorte2026!`
- Rol esperado: `OPERATOR`
- Nota: credencial valida para entorno local y pruebas; en despliegues reales debe redefinirse desde backend.

## Modulos visibles esperados despues del login
- `Agendamento de Massagens`
- `Aluguel de Quadras de Tenis`
- `Tours e Viagens`
- `Configuracoes`

Nota de idioma:
- La UI visible al operador debe salir en portugues de Brasil (`pt-BR`).

## Pruebas y analisis recomendados
```powershell
flutter test
flutter analyze
```

## Build instalable Windows
```powershell
flutter build windows --release --dart-define=COSTANORTE_API_BASE_URL=http://127.0.0.1:8080/api/v1
```

## Build Web
```powershell
flutter build web --release --dart-define=COSTANORTE_API_BASE_URL=https://quadras-back-production-4973.up.railway.app/api/v1
```

Si el backend web no comparte origen:

```powershell
flutter build web --release --dart-define=COSTANORTE_API_BASE_URL=https://mi-backend.ejemplo.com/api/v1
```

Salida esperada:
- Binarios en `build/windows/x64/runner/Release/` (ejemplo: `costanorte.exe`).
- Sitio web estatico listo para publicar en `build/web/`.

## Publicacion en Hostinger
- Backend productivo configurado para el frontend web: `https://quadras-back-production-4973.up.railway.app/api/v1`.
- Generar el build:

```powershell
flutter build web --release --dart-define=COSTANORTE_API_BASE_URL=https://quadras-back-production-4973.up.railway.app/api/v1
```

- Abrir el Administrador de archivos de Hostinger o usar FTP.
- Entrar a `public_html/`.
- Subir el contenido de `build/web/` directo a `public_html/`.
- Confirmar que `.htaccess` tambien quede publicado; ese archivo resuelve rutas internas de Flutter Web.
- Si el sitio no va en la raiz del dominio, reconstruir con `--base-href /ruta-publica/`.
- Si Hostinger sirve el sitio pero el login falla, revisar CORS en Railway para permitir el dominio final del frontend.

## Script de preflight (opcional recomendado)
```powershell
.\scripts\frontend_preflight.ps1
```

Para build local de Windows:
```powershell
.\scripts\frontend_preflight.ps1 -Target windows -ApiBaseUrl http://127.0.0.1:8080/api/v1
```

## Nota operativa
- Si el backend corre en otra IP/puerto, ajustar `COSTANORTE_API_BASE_URL`.
- Compatibilidad temporal: tambien se acepta `QUEDRAS_API_BASE_URL`.
- En web, si no se define `COSTANORTE_API_BASE_URL`, el frontend consume por defecto `https://quadras-back-production-4973.up.railway.app/api/v1`.
- Si frontend y backend web viven en distinto origen, el backend debe habilitar CORS para `Authorization`, `Content-Type`, `Accept` y metodos `GET, POST, PUT, PATCH, DELETE`.
- El login consume `POST /api/v1/auth/login` y las pantallas protegidas envian `Authorization: Bearer <jwt>`.
- `Quadras` es el unico modulo ya conectado a backend real en esta fase; `Massagens` y `Tours e Viagens` permanecen en estado frontend controlado hasta definir contrato dedicado.
