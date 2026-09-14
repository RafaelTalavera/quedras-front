# Aviso manual de órdenes de mantenimiento de AA

Fecha: 2026-09-14.

## Alcance

La acción **AA** crea órdenes para el prestador de especialidad
`AIR_CONDITIONING`. El aviso usa el mismo flujo manual de todas las órdenes de
mantenimiento; no hay envío automático ni un texto distinto para AA.

Al guardar una orden de AA con un prestador habilitado para WhatsApp, el sistema
muestra la confirmación de guardado y después la vista previa del aviso. La
acción **Avisar no WhatsApp** en una orden existente abre esa misma vista previa.
El número procede de `whatsappNumber`; el contacto general no se usa como
destinatario. Una orden sin número WhatsApp válido se puede guardar, pero no
preparar para WhatsApp.

## Pasos del operador

1. Abrir **Manutenção > AA**, elegir el prestador y completar la orden.
2. Guardar y comprobar el aviso: prestador, número, local, servicio, agenda,
   estado y descripción.
3. Pulsar **WhatsApp Web** o, en la aplicación Flutter de Windows,
   **Aplicativo Windows**. El texto se copia al portapapeles antes de intentar
   abrir el canal.
4. Si WhatsApp abre la conversación con el campo vacío, pegar con **Ctrl+V**.
   Verificar número y texto, y pulsar **Enviar** dentro de WhatsApp.

El enlace intenta precargar el texto, pero abrir WhatsApp no prueba que se haya
enviado. Si falla la apertura, el aviso copiado sigue disponible para pegarlo
manualmente. Si el navegador deniega acceso al portapapeles, el diálogo informa
del fallo y mantiene la vista previa seleccionable y el botón **Copiar texto**.

## Verificación automatizada

- `flutter test test/core/whatsapp/manual_whatsapp_dialog_test.dart`: comprueba
  número, texto, caracteres especiales y orden **copiar → abrir**.
- `flutter analyze lib/core/whatsapp/manual_whatsapp_dialog.dart
  test/core/whatsapp/manual_whatsapp_dialog_test.dart`: sin problemas.

Pendiente: prueba manual en navegador con sesión de WhatsApp Web y en Windows
con la aplicación instalada. La prueba automatizada simula el lanzador externo;
no puede confirmar lo que WhatsApp muestra ni el envío efectivo.
