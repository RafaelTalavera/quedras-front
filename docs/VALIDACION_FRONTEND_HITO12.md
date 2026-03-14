# VALIDACION FRONTEND HITO 12 - COSTANORTE

## Alcance validado
- Pantalla de login inicial integrada con backend JWT local.
- Sesion en memoria mediante `SessionController`.
- Guard de rutas: sin sesion se fuerza `/login`; con sesion se redirige a dashboard.
- Logout manual desde shell y redireccion a login.
- Cliente HTTP autenticado con `Authorization: Bearer <token>` y limpieza de sesion ante `401`.

## Usuario demo para pruebas
- Username: `operador.demo`
- Password: `Costanorte2026!`
- Rol: `OPERATOR`

## Validaciones ejecutadas el 2026-03-14

### 1. Suite automatizada
```powershell
flutter test
```
- Resultado: OK
- Cobertura validada adicional en Hito 12:
  - `test/core/network/authorized_api_client_test.dart`
  - `test/features/auth/infrastructure/http_auth_app_service_test.dart`
  - `test/widget_test.dart`

### 2. Analisis estatico
```powershell
flutter analyze
```
- Resultado: OK
- Observacion: sin issues, warnings ni lints pendientes.

### 3. Build release Windows
```powershell
flutter build windows --release
```
- Resultado: OK
- Artefacto generado: `build/windows/x64/runner/Release/costanorte.exe`

## Flujo operativo esperado
1. Abrir la app desktop.
2. Ingresar `operador.demo` y `Costanorte2026!`.
3. Verificar acceso al dashboard.
4. Navegar a agenda o nueva reserva y confirmar que el backend responde con sesion autenticada.
5. Ejecutar logout y validar regreso inmediato al login.

## Observaciones
- La sesion actual es en memoria; al reiniciar la app se requiere nuevo login.
- El frontend queda preparado para ampliar la validacion de roles cuando backend agregue nuevos perfiles.
- La credencial demo es solo para pruebas locales y debe cambiarse por variables/configuracion del backend fuera de ese contexto.
