# INSTALACION FRONTEND - COSTANORTE

## Objetivo
Instalar y ejecutar el cliente Flutter Desktop conectado al backend local del hotel.

## Prerequisitos
- Windows 10/11.
- Flutter SDK estable instalado.
- Visual Studio 2022 con workload `Desktop development with C++` (incluyendo MSVC, CMake tools y Windows SDK).
- `flutter doctor -v` sin errores bloqueantes para desktop Windows.
- Backend COSTANORTE operativo en red local.

## Validacion del entorno Flutter
```powershell
flutter doctor -v
```

## Ejecucion en desarrollo (con backend local)
```powershell
flutter run -d windows --dart-define=COSTANORTE_API_BASE_URL=http://127.0.0.1:8080/api/v1
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

Salida esperada:
- Binarios en `build/windows/x64/runner/Release/` (ejemplo: `costanorte.exe`).

## Script de preflight (opcional recomendado)
```powershell
.\scripts\frontend_preflight.ps1
```

## Nota operativa
- Si el backend corre en otra IP/puerto, ajustar `COSTANORTE_API_BASE_URL`.
- Compatibilidad temporal: tambien se acepta `QUEDRAS_API_BASE_URL`.
- La app no depende de internet para operar, solo de conectividad con backend local.
- El login consume `POST /api/v1/auth/login` y las pantallas protegidas envian `Authorization: Bearer <jwt>`.
- `Quadras` es el unico modulo ya conectado a backend real en esta fase; `Massagens` y `Tours e Viagens` permanecen en estado frontend controlado hasta definir contrato dedicado.
