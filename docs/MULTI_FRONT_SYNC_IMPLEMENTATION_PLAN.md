# ESTADO Y CRITERIO DE OPERACION - SINCRONIZACION MULTI-FRONT

## Objetivo
- Operar con un backend central y multiples instalaciones del frontend dentro del hotel.
- Mantener una separacion estricta entre `quadras` como API y `quedras-front` como cliente.
- Reflejar cambios entre terminales sin `polling` periodico.

## Estado actual implementado
- El frontend consume un backend HTTP configurable por `COSTANORTE_API_BASE_URL` o `QUEDRAS_API_BASE_URL`.
- El valor por defecto actual apunta a `http://127.0.0.1:8080/api/v1`.
- `quadras` ya no publica frontend HTML/JS embebido.
- El frontend mantiene una conexion `SSE` autenticada hacia `GET /api/v1/sync/events`.
- Las pantallas operativas se recargan cuando llega un evento relevante para la vista abierta.

## Decision recomendada
- Mantener `localhost` como entorno de desarrollo diario.
- Agregar un entorno de pruebas en red para validar multiples terminales conectadas al mismo backend.
- Mantener `SSE` como mecanismo principal de sincronizacion multi-terminal.
- Reservar `WebSocket` solo si mas adelante aparece una necesidad real de comunicacion bidireccional.

## Ambientes propuestos

### 1. Local
- Uso:
  - desarrollo diario
  - debugging rapido
  - trabajo simultaneo de frontend y backend en una sola maquina
- URL esperada:
  - `http://127.0.0.1:8080/api/v1`
- Alcance:
  - no valida sincronizacion real entre varias terminales

### 2. Test-red
- Uso:
  - pruebas funcionales multi-maquina dentro de la red local
  - validacion de concurrencia operativa
  - validacion de refresco entre frontends
- URL esperada:
  - `http://<ip-servidor-o-ip-dev>:8080/api/v1`
- Alcance:
  - simula la operacion real del hotel

### 3. Produccion
- Uso:
  - operacion del hotel con backend centralizado
- URL esperada:
  - IP fija o dominio interno del servidor
- Alcance:
  - todas las terminales deben consumir la misma API
  - no se debe usar `localhost`

## Backend

### Fase 1. Ambientes y despliegue base
- Definir propiedades por ambiente:
  - `local`
  - `test-red`
  - `prod`
- Externalizar configuracion sensible:
  - host
  - puerto
  - CORS
  - JWT
  - logging
- Confirmar que el backend puede exponerse en red interna y no solo en loopback.
- Documentar URL canonica por ambiente.

### Fase 2. Contrato de lectura consistente
- Revisar que todos los endpoints usados por frontend devuelvan el estado persistido mas reciente.
- Asegurar respuestas completas luego de:
  - crear
  - editar
  - cancelar
  - informar pago
- Estandarizar timestamps de auditoria para poder detectar cambios recientes y ordenar correctamente.

### Sincronizacion vigente
- Endpoint de eventos:
  - `GET /api/v1/sync/events`
- Los servicios publican eventos livianos post-commit.
- Los dominios cubiertos hoy son:
  - `reservations`
  - `massages`
  - `courts`
  - `tours`
  - `maintenance`
- Cada evento informa:
  - `domain`
  - `action`
  - `entityId`
  - `dateFrom`
  - `dateTo`

### Fase 4. Observabilidad operativa
- Registrar en logs:
  - usuario autenticado
  - terminal o origen si existe identificador
  - accion
  - timestamp
- Facilitar diagnostico de conflictos operativos entre terminales.

### Criterio
- El backend no debe alojar pantallas ni assets del frontend.
- La validacion final de concurrencia sigue resolviendose en backend.

## Frontend

### Configuracion por ambiente
- Formalizar perfiles de ejecucion:
  - `local`
  - `test-red`
  - `prod`
- Mantener `localhost` para desarrollo diario.
- Ejecutar `test-red` apuntando a una IP compartida en la red.
- Documentar comandos de `flutter run` y `flutter build` por ambiente.

### Sincronizacion vigente
- Modulos cubiertos:
  - `Massagens`
  - `Quadras`
  - `Tours`
  - `Maintenance`
- Regla comun:
  - escuchar eventos del backend
  - refrescar solo si el evento impacta la vista abierta
  - volver a cargar al retomar la app
- Ya no se usa `Timer.periodic` como estrategia principal de sincronizacion.

## Orden de validacion recomendado
1. Backend:
   exponer correctamente ambientes y servidor accesible por red.
2. Backend:
   validar el endpoint `/api/v1/sync/events` con autenticacion.
3. Frontend:
   ejecutar dos o mas terminales contra la misma API.
4. QA:
   verificar creacion, edicion, pago, cancelacion y cambios de maintenance.

## Casos de prueba minimos

### Caso 1. Alta visible desde otra terminal
- Terminal A crea una reserva o atendimento.
- Terminal B debe verla sin esperar un intervalo fijo.

### Caso 2. Cancelacion concurrente
- Terminal A abre un registro.
- Terminal B lo cancela.
- Terminal A intenta operarlo nuevamente.
- El backend debe rechazar la accion y el frontend debe informar el conflicto.

### Caso 3. Pago concurrente
- Terminal A deja abierta una reserva no paga.
- Terminal B informa pago.
- Terminal A debe ver el cambio tras el refresco y no volver a pagar sin validacion.

### Caso 4. Falla de red temporal
- La terminal pierde conectividad.
- El frontend debe mostrar error recuperable y retomar recarga cuando el backend vuelva a responder.

## Riesgos y mitigaciones
- Riesgo:
  refrescos automaticos pueden romper formularios abiertos.
  Mitigacion:
  filtrar eventos por pantalla y mantener validaciones finales en backend.
- Riesgo:
  usar `localhost` fuera de desarrollo rompe la arquitectura centralizada.
  Mitigacion:
  documentar y validar ambiente antes de despliegue.
- Riesgo:
  inconsistencias por concurrencia entre terminales.
  Mitigacion:
  mantener las validaciones definitivas en backend.

## Entregables documentales
- Documento de ambientes y despliegue frontend.
- Documento equivalente en backend con propiedades por ambiente.
- Procedimiento de QA multi-terminal con dos o mas PCs.
- Checklist de salida a produccion para confirmar:
  - URL correcta
  - conectividad de red
  - login
  - refresco
  - manejo de conflictos

## Criterio de cierre
- El equipo puede ejecutar la app en `local`, `test-red` y `prod` sin cambiar codigo fuente.
- Varias terminales consumen el mismo backend en red.
- Los cambios hechos en una terminal se reflejan en las demas por eventos del backend.
- Los conflictos operativos se resuelven en backend con mensajes claros en frontend.
- Existe documentacion suficiente para instalar, probar y operar el sistema en el hotel.
