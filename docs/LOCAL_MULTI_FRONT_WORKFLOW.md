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

## Comandos recomendados

### Desarrollo local diario
```powershell
flutter run -d windows `
  --dart-define=COSTANORTE_APP_ENV=local `
  --dart-define=COSTANORTE_API_BASE_URL=http://127.0.0.1:8080/api/v1
```

### Prueba multi-front en red local
```powershell
flutter run -d windows `
  --dart-define=COSTANORTE_APP_ENV=test-red `
  --dart-define=COSTANORTE_API_BASE_URL=http://192.168.1.50:8080/api/v1
```

## Comportamiento implementado en frontend
- `Massagens`, `Quadras`, `Tours` y `Maintenance` escuchan eventos emitidos por backend.
- La recarga se ejecuta solo cuando el evento afecta la pantalla visible.
- La app tambien vuelve a consultar al retomar foco.
- Ya no se usa `polling` periodico para mantener sincronizadas las terminales.

## Escenario recomendado de prueba
1. Levantar el backend en una maquina accesible por IP local.
2. Abrir dos frontends apuntando a esa misma IP.
3. En la terminal A:
   crear, pagar o cancelar un registro.
4. En la terminal B:
   verificar que el cambio se refleje automaticamente por el canal de eventos.

## Nota
- La validacion definitiva de concurrencia sigue dependiendo del backend.
- Este repo cubre la parte frontend previa a deploy.
