# PLAN FRONTEND - OPERACION WHATSAPP

> **Histórico, sustituido el 2026-09-14.** Ver
> `../../quadras/docs/WHATSAPP_MANUAL_MIGRATION_2026-09-14.md` para la
> decisión manual vigente y su ejecución.

Fecha: 2026-08-18  
Estado: Base implementada; activacion Meta pendiente  
Tipo: Cross-repo  
Documento canonico de dominio y backend:
`C:/Users/Public/Documents/Proyectos/quadras/docs/WHATSAPP_CLOUD_API_INTEGRATION_PLAN.md`

## Objetivo

Preparar el frontend Flutter para observar la comunicacion automatica de
`Massagens` y `Manutencao`, resolver propuestas de visita y administrar limites y
costos desde `Configuracoes`, sin exponer credenciales de Meta.

## Cambios por modulo

### Massagens

- separar `contact` de `whatsappNumber` en el catalogo de prestadores;
- agregar habilitacion y estado de consentimiento para WhatsApp;
- mostrar en cada atencion: no aplica, pendiente, enviado, entregado, aceptado,
  rechazado, vencido o fallido;
- no ofrecer propuesta de fecha al prestador;
- no llamar WhatsApp desde Flutter cuando la integracion Cloud este activa;
- mantener el flujo manual actual como fallback visible y auditado durante la
  transicion, no ejecutarlo automaticamente al guardar.

### Manutencao

- separar `contact` de `whatsappNumber` y exigir proveedor `EXTERNAL` para envio;
- mostrar estado de solicitud y ultima entrega;
- mostrar propuesta de visita con fecha, franja y observacion;
- permitir aceptar o rechazar la propuesta sin editar silenciosamente la orden;
- advertir si la orden cambio desde que se genero la propuesta;
- retirar el lanzamiento automatico `whatsapp://` al guardar una vez activado Cloud.

### Configuracoes > WhatsApp

Visible solo para `SUPERVISOR`:

- KPIs mensuales de cola, envio, entrega, lectura, fallos y respuestas;
- costo estimado, costo conciliado y presupuesto consumido en BRL;
- desglose por Massagens/Manutencao y por tipo de mensaje;
- limite duro, alertas, limites de volumen, kill switch y `DRY_RUN`;
- salud del webhook, ultima recepcion y cola de errores;
- reintento manual con confirmacion y motivo obligatorio;
- numeros siempre enmascarados salvo en formularios autorizados.

## Arquitectura frontend

- crear feature `lib/features/whatsapp/` con `domain`, `application`,
  `infrastructure` y `presentation`;
- agregar contratos HTTP para settings, uso, mensajes y propuestas;
- integrar el panel como subseccion de Settings, no como modulo operativo principal;
- reutilizar autenticacion JWT y manejo uniforme de errores;
- refrescar estados por SSE existente o polling acotado; no hacer polling por fila;
- el frontend nunca conoce access token, app secret ni verify token.

## Secuencia de entrega

1. Modelos y cliente HTTP alineados con backend.
2. Catalogos de proveedores con campos WhatsApp separados.
3. Indicadores de estado en Massagens y Manutencao.
4. Bandeja de propuestas de visita.
5. Panel supervisor, presupuesto y limites.
6. Remocion del envio automatico manual al activar Cloud API.
7. Pruebas responsive, permisos y punta a punta con backend real.

## Criterio de cierre

- ningun secreto de Meta aparece en Flutter;
- operador puede saber si el proveedor recibio/respondio sin abrir otra herramienta;
- mantenimiento permite resolver propuestas de visita;
- masajes conserva fecha/hora definida por el huesped;
- supervisor puede detener envios y controlar volumen/costo;
- frontend y backend usan el mismo contrato y se validan juntos.

## Registro de implementacion 2026-08-18

- Se extendieron modelos y payloads de proveedores con numero y habilitacion
  WhatsApp separados.
- El catalogo de masajes permite configurar numero y envio automatico.
- El catalogo de mantenimiento restringe la habilitacion automatica a externos.
- Settings muestra el panel supervisor con consumo, costo, presupuesto, limites,
  kill switch y modo de simulacion.
- Se agregaron lecturas y actualizacion HTTP sobre `/settings/whatsapp`.
- `flutter analyze lib/features/settings lib/features/massages
  lib/features/maintenance` finaliza sin errores.
- La suite completa conserva un fallo de widget preexistente en
  `massage_booking_page_test.dart`: busca la opcion textual `Huesped`, que ya no
  aparece en el dropdown actual. El fallo no esta relacionado con los contratos
  WhatsApp y debe corregirse junto con la prueba de esa pantalla.
