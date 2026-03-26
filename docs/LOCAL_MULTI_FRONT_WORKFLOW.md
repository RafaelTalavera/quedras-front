# FLUJO LOCAL Y TEST-RED ANTES DE DEPLOY

## Objetivo
- Seguir desarrollando en local sin bloquear el trabajo diario.
- Poder probar sincronizacion entre multiples frontends antes de cualquier despliegue formal.

## Variables runtime frontend
- `COSTANORTE_API_BASE_URL`
  - URL base de la API.
- `COSTANORTE_APP_ENV`
  - valores esperados:
    - `local`
    - `test-red`
    - `prod`
- `COSTANORTE_AUTO_REFRESH_SECONDS`
  - override opcional del intervalo de auto refresh.
  - `0` desactiva el polling.

## Comandos recomendados

### Desarrollo local diario
```powershell
flutter run -d windows `
  --dart-define=COSTANORTE_APP_ENV=local `
  --dart-define=COSTANORTE_API_BASE_URL=http://127.0.0.1:8080/api/v1 `
  --dart-define=COSTANORTE_AUTO_REFRESH_SECONDS=0
```

### Prueba multi-front en red local
```powershell
flutter run -d windows `
  --dart-define=COSTANORTE_APP_ENV=test-red `
  --dart-define=COSTANORTE_API_BASE_URL=http://192.168.1.50:8080/api/v1 `
  --dart-define=COSTANORTE_AUTO_REFRESH_SECONDS=20
```

## Comportamiento implementado en frontend
- `Massagens`, `Quadras` y `Tours` tienen boton manual de `Atualizar`.
- En `test-red` y `prod` el polling operativo queda activo por defecto cada `20` segundos.
- En `local` el polling queda desactivado por defecto para no interferir con desarrollo.
- El refresh automatico se pausa cuando:
  - la app no esta activa
  - la pantalla no es la ruta actual
  - hay operaciones de guardado en curso

## Escenario recomendado de prueba
1. Levantar el backend en una maquina accesible por IP local.
2. Abrir dos frontends apuntando a esa misma IP.
3. En la terminal A:
   crear, pagar o cancelar un registro.
4. En la terminal B:
   verificar el cambio con boton manual o esperar el siguiente ciclo de polling.

## Nota
- La validacion definitiva de concurrencia sigue dependiendo del backend.
- Este repo cubre la parte frontend previa a deploy.
