## Objetivo

Cerrar la primera fase operativa de mantenimiento para:

- emitir ordenes con salida directa a WhatsApp del responsable;
- normalizar el numero del responsable desde frontend;
- mejorar la usabilidad de `Catalogos` en `Locais` y `Responsaveis`.

## Cambios funcionales

- Al guardar una orden de mantenimiento, el sistema intenta abrir WhatsApp del responsable seleccionado con el mensaje precargado.
- Si no puede abrir la app, intenta WhatsApp Web.
- Si tampoco puede abrir WhatsApp, copia el mensaje al portapapeles.
- El guardado de la orden exige responsable con WhatsApp valido.

## Criterio de datos

- Se reutiliza el campo `contact` del proveedor como numero de WhatsApp.
- El numero se normaliza a formato internacional con solo digitos.
- Si el dato no es valido, no se permite guardar el responsable ni la orden asociada.

## Cambios de UI en Catalogos

### Locais

- Lista izquierda con buscador por texto.
- Formulario lateral mas ancho.
- Formulario lateral scrollable.
- Layout responsive con mejor comportamiento en anchos reducidos.
- Separacion visual superior antes del campo `Tipo`.

### Responsaveis

- Lista izquierda con buscador por texto.
- Formulario lateral mas ancho.
- Formulario lateral scrollable.
- Dropdowns con expansion horizontal para evitar truncado.
- Separacion visual superior antes del campo `Tipo`.

## Riesgos conocidos

- El campo `contact` sigue siendo generico a nivel API; no existe aun `whatsappNumber`.
- No hay auditoria backend de intento o resultado del envio por WhatsApp.
- La salida a WhatsApp depende de disponibilidad de app o sesion de WhatsApp Web en el dispositivo del usuario.

## Siguiente fase sugerida

- Separar `contact` y `whatsappNumber` en backend.
- Registrar auditoria de notificacion por orden.
- Replicar el mismo layout responsive apilado en `Responsaveis` cuando el dialogo quede por debajo del ancho de corte definido para `Locais`.
