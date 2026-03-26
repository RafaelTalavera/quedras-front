# PLAN DE IMPLEMENTACION - AMBIENTES Y SINCRONIZACION MULTI-FRONT

## Objetivo
- Preparar la aplicacion para operar con un backend central y multiples instalaciones del frontend dentro del hotel.
- Definir una estrategia de ambientes clara para desarrollo, pruebas en red y produccion.
- Incorporar sincronizacion de datos entre terminales sin introducir complejidad innecesaria en la primera fase.

## Estado actual observado
- El frontend consume un backend HTTP configurable por `COSTANORTE_API_BASE_URL` o `QUEDRAS_API_BASE_URL`.
- El valor por defecto actual apunta a `http://127.0.0.1:8080/api/v1`.
- Las pantallas cargan datos al abrirse o al ejecutar acciones locales de guardar, pagar o cancelar.
- No existe hoy un mecanismo de actualizacion automatica entre distintos frontends:
  - no hay `WebSocket`
  - no hay `Server-Sent Events`
  - no hay `polling` periodico

## Decision recomendada
- Mantener `localhost` como entorno de desarrollo diario.
- Agregar un entorno de pruebas en red para validar multiples terminales conectadas al mismo backend.
- Implementar sincronizacion en dos etapas:
  1. `refresh` y recargas controladas
  2. `polling` periodico en modulos operativos
- Dejar `WebSocket` o `SSE` como fase posterior solo si operacion exige actualizacion inmediata.

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

## Plan de implementacion backend

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

### Fase 3. Soporte para sincronizacion simple
- Preparar endpoints de listado para recarga frecuente sin efectos colaterales.
- Validar rendimiento de consultas para uso repetido en agenda y reportes.
- Si es necesario, agregar filtros por fecha y ultima actualizacion para reducir payload.
- Definir una estrategia simple de control de concurrencia:
  - validacion de conflictos de horario en backend
  - rechazo de operaciones sobre registros ya cancelados o pagados segun regla

### Fase 4. Observabilidad operativa
- Registrar en logs:
  - usuario autenticado
  - terminal o origen si existe identificador
  - accion
  - timestamp
- Facilitar diagnostico de conflictos operativos entre terminales.

### Fase 5. Evolucion opcional a tiempo real
- Dejar evaluado, no obligatorio en primera entrega:
  - `WebSocket`
  - `Server-Sent Events`
- Solo avanzar a esta fase si el hotel necesita reflejo casi inmediato y el `polling` no alcanza.

## Plan de implementacion frontend

### Fase 1. Configuracion por ambiente
- Formalizar perfiles de ejecucion:
  - `local`
  - `test-red`
  - `prod`
- Mantener `localhost` para desarrollo diario.
- Ejecutar `test-red` apuntando a una IP compartida en la red.
- Documentar comandos de `flutter run` y `flutter build` por ambiente.

### Fase 2. Recarga controlada de pantallas
- Identificar modulos operativos que requieren ver cambios externos:
  - `Massagens`
  - `Quadras`
  - `Tours`
  - agenda general si sigue vigente
- Unificar una regla minima de refresco:
  - recargar al entrar a la pantalla
  - recargar al volver desde dialogs de operacion
  - exponer boton manual de `refresh` donde aplique

### Fase 3. Polling periodico
- Agregar `polling` solo en vistas operativas donde el dato cambia durante el dia.
- Frecuencia inicial recomendada:
  - cada `15` o `30` segundos
- Reglas:
  - pausar cuando la pantalla no esta visible
  - evitar disparar varias cargas en paralelo
  - no sobrescribir formularios en edicion
  - mantener feedback visual discreto cuando hay datos nuevos

### Fase 4. Manejo de datos actualizados por terceros
- Definir comportamiento cuando otra terminal cambia un registro abierto en pantalla:
  - refresco silencioso si no hay edicion en curso
  - aviso al operador si el registro ya cambio
- En formularios de accion:
  - revalidar antes de confirmar guardado
  - mostrar mensaje claro si backend detecta conflicto

### Fase 5. Estandarizacion tecnica
- Centralizar la logica de refresco periodico para no duplicar timers en cada feature.
- Definir una politica comun para:
  - `loading`
  - errores de red
  - cancelacion de requests al salir de pantalla
  - conservacion de filtros activos

## Orden recomendado de ejecucion
1. Backend:
   exponer correctamente ambientes y servidor accesible por red.
2. Frontend:
   formalizar ambientes `local`, `test-red` y `prod`.
3. Backend:
   asegurar endpoints de lectura consistentes y validaciones de concurrencia.
4. Frontend:
   implementar recarga controlada y `refresh` manual uniforme.
5. Frontend:
   agregar `polling` en `Massagens`, `Quadras` y `Tours`.
6. QA:
   probar con al menos dos terminales apuntando al mismo backend.
7. Evaluacion:
   decidir si `polling` alcanza o si hace falta evolucionar a tiempo real.

## Casos de prueba minimos

### Caso 1. Alta visible desde otra terminal
- Terminal A crea una reserva o atendimento.
- Terminal B debe verla luego del refresco manual o del siguiente ciclo de `polling`.

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
  `polling` demasiado agresivo puede cargar innecesariamente al backend.
  Mitigacion:
  empezar con `15` o `30` segundos y medir.
- Riesgo:
  refrescos automaticos pueden romper formularios abiertos.
  Mitigacion:
  pausar refresco mientras el operador esta editando.
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
- Los cambios hechos en una terminal se reflejan en las demas por `refresh` manual o `polling`.
- Los conflictos operativos se resuelven en backend con mensajes claros en frontend.
- Existe documentacion suficiente para instalar, probar y operar el sistema en el hotel.
