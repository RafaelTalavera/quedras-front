# COSTANORTE Frontend

Cliente Flutter Desktop para operacion interna de servicios del hotel.

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
- `docs/VALIDACION_FRONTEND_HITO12.md`
- `docs/VALIDACION_FRONTEND_HITO10.md`
- `docs/FRONT_PROGRESS.md`
- `docs/FRONT_CHANGELOG.md`
- `docs/FRONT_AGENT_GUIDELINES.md`
- `docs/INTERNAL_NAVIGATION_STANDARD.md`
- `docs/CALENDAR_LAYOUT_STANDARD.md`
- `docs/MASSAGES_PROVIDER_ADD_STANDARD.md`
- `docs/MASSAGES_SUMMARY_REPORT_PLAN.md`
- `docs/SYSTEM_OPERATION_RULES.md`
- `docs/BACKEND_MASSAGES_ADJUSTMENT_PLAN.md`
