# QUEDRAS Frontend

Cliente Flutter Desktop para operacion interna de reservas de cancha.

## Ejecucion local
```powershell
flutter run -d windows --dart-define=QUEDRAS_API_BASE_URL=http://127.0.0.1:8080/api/v1
```

## Validacion tecnica
```powershell
flutter test
flutter analyze
```

## Build de Windows
```powershell
flutter build windows --release --dart-define=QUEDRAS_API_BASE_URL=http://127.0.0.1:8080/api/v1
```

## Documentacion de soporte
- `docs/INSTALACION_FRONTEND_HOTEL.md`
- `docs/VALIDACION_FRONTEND_HITO10.md`
- `docs/FRONT_PROGRESS.md`
