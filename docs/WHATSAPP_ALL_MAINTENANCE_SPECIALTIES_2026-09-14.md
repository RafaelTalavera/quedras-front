# Aviso manual por WhatsApp para todas las ordenes de mantenimiento

Fecha: 2026-09-14. Alcance: frontend `quedras-front`; el contrato y la
persistencia de prestadores del backend no cambian en esta correccion.

El criterio comun vigente para todos los modulos esta documentado en
`WHATSAPP_MANUAL_OPERATION_STANDARD.md`; esta nota conserva los detalles
especificos de mantenimiento.

## Comportamiento

AA es el patron operativo. Elevadores, Portas e janelas, Internet, Camaras,
Telefones, TI e Interno usan el mismo texto y el mismo dialogo de preparacion
de WhatsApp. Despues de guardar una orden se muestra la vista previa aunque el
contacto WhatsApp todavia no este configurado.

Si el prestador tiene `whatsappNumber` internacional valido y
`whatsappEnabled = true`, el operador puede abrir Web o la aplicacion Windows
con la conversacion dirigida al proveedor. El texto se copia antes de abrir el
canal y el operador confirma **Enviar** dentro de WhatsApp.

Si falta numero o habilitacion, el dialogo mantiene los mismos controles
principales: **Copiar texto** y **WhatsApp Web**. En Windows tambien muestra
**Aplicativo Windows**. En ese caso WhatsApp se abre sin destinatario; el
operador selecciona el contacto manualmente y pega el texto con Ctrl+V.

El catalogo permite habilitar WhatsApp tambien para un prestador **Interno**.
El backend ya admitia esta configuracion; la limitacion estaba en el formulario
Flutter. Al seleccionar entre varios prestadores activos de la misma
especialidad, se prioriza uno con WhatsApp listo, sin cambiar el prestador de
ordenes ya guardadas.

## Datos que debe completar el operador

Los prestadores iniciales de las migraciones no contienen numeros reales ni
estan habilitados para WhatsApp. En **Catalogos > Prestadores**, editar cada
especialidad, cargar su numero internacional y activar **Disponivel para
contato por WhatsApp**. No se inventaron telefonos ni se enviaron mensajes.

## Verificacion

- Prueba de seleccion para todas las especialidades, incluido Interno.
- Prueba del dialogo sin numero: mantiene el aviso, muestra WhatsApp Web,
  copia el texto y abre `web.whatsapp.com` para seleccion manual del contacto.
- Suite frontend y analisis estatico, mas prueba manual pendiente con numeros
  reales y sesion de WhatsApp Web/Windows.

## Destino verificable

AA, Elevadores y cada otra especialidad usan el mismo preparador. El destino
no depende del texto del boton: depende del `providerId` que queda guardado en
la orden. Al abrir una especialidad, el formulario preselecciona su prestador;
al guardar, el dialogo muestra el nombre y el numero del prestador asociado a
esa orden.

Para que Elevadores abra la misma conversacion que AA, el numero debe estar
guardado y habilitado en el prestador de **Elevadores** seleccionado por la
orden. Un numero existente en otro prestador no cambia ese destino. Si falta
numero o habilitacion, el dialogo igualmente copia el texto y permite abrir
WhatsApp para elegir el contacto de forma manual.
