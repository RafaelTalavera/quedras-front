# ESTANDAR OPERATIVO - AVISO MANUAL POR WHATSAPP

Fecha: 2026-09-20  
Patron de referencia: orden de aire acondicionado (AA) de `Manutencao`.

## Objetivo

Toda comunicacion operativa por WhatsApp se prepara desde el sistema, pero el
operador confirma el envio dentro de WhatsApp. Guardar una orden o reserva
nunca depende de que WhatsApp este disponible.

## Flujo obligatorio

1. Persistir primero la operacion.
2. Mostrar la confirmacion de guardado.
3. Abrir el dialogo comun `showManualWhatsappDialog` con destinatario, numero y
   texto de la operacion.
4. Copiar el texto al portapapeles al elegir Web o Windows y abrir WhatsApp con
   la conversacion dirigida cuando el numero sea valido.
5. El operador verifica el destinatario y pulsa **Enviar** dentro de WhatsApp.

El mismo dialogo debe estar disponible tambien desde una operacion existente
mediante la accion **Avisar no WhatsApp**.

## Sin numero configurado

La ausencia de numero no bloquea la operacion ni oculta el aviso. El dialogo
debe conservar **Copiar texto** y **WhatsApp Web**; WhatsApp se abre sin chat
preseleccionado para que el operador elija el contacto y pegue con `Ctrl+V`.

## Destinatarios y datos

| Modulo | Destinatario | Campo |
| --- | --- | --- |
| Manutencao | Prestador de la orden | `whatsappNumber` + `whatsappEnabled` |
| Massagens | Cliente o massagista seleccionado | `clientWhatsappNumber`; `MassageTherapist.whatsappNumber` + habilitacion |
| Quadras | Reservante | `customerWhatsappNumber` |

Los numeros se normalizan a 10--15 digitos. Nunca se inventan numeros ni se
considera enviado un aviso por el solo hecho de abrir WhatsApp.

En Quadras el numero se persiste en la propia reserva. El contrato API lo
acepta tanto al crear como al editar y lo devuelve al consultar la agenda;
backend lo incorpora mediante la migracion `V35__add_court_booking_whatsapp.sql`.
Para Brasil se debe registrar el formato internacional: `55` + DDD + numero.

## Implementacion de referencia

- Dialogo compartido: `lib/core/whatsapp/manual_whatsapp_dialog.dart`.
- Manutencao: `_prepareOrderWhatsapp`.
- Massagens: `_shareBooking` con selector Cliente/Massagista.
- Quadras: `_shareBookingReceipt`.

No se debe sustituir este flujo por el compartido generico del sistema para
avisos operativos. El compartido generico queda reservado para archivos, por
ejemplo reportes PDF.

## Verificacion manual

1. Probar una operacion con numero habilitado: debe abrir el chat correcto y
   copiar el texto.
2. Probar sin numero: debe abrir WhatsApp sin chat, mantener el texto copiado
   y permitir enviarlo manualmente.
3. Confirmar que cerrar el dialogo o WhatsApp no altera el estado de la
   operacion.
