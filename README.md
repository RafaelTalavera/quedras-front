# COSTANORTE Frontend

Cliente Flutter Desktop para operacion interna de reservas de cancha.

## Ejecucion local
```powershell
flutter run -d windows --dart-define=COSTANORTE_API_BASE_URL=http://127.0.0.1:8080/api/v1
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

Compatibilidad temporal:
- El cliente tambien acepta `QUEDRAS_API_BASE_URL` mientras se completa la migracion de entornos.

## Documentacion de soporte
- `docs/INSTALACION_FRONTEND_HOTEL.md`
- `docs/VALIDACION_FRONTEND_HITO10.md`
- `docs/FRONT_PROGRESS.md`
