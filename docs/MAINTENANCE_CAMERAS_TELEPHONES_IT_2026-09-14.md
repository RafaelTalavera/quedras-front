# Órdenes de mantenimiento: Câmeras, Telefones y TI

Fecha: 2026-09-14. Repositorios: `quadras` y `quedras-front`.

## Alcance

Se agregaron tres accesos a **Criar ordem** y tres especialidades de prestador:

| Botón | Código API | Prestador inicial |
| --- | --- | --- |
| Câmeras | `CAMERAS` | Servico de cameras |
| Telefones | `TELEPHONES` | Servico de telefonia |
| TI | `IT_SUPPORT` | Servico de TI |

Cada botón preselecciona un prestador de su especialidad. Las órdenes siguen el
flujo normal de mantenimiento; no se creó un estado ni un modelo de orden
paralelo. Internet y Portas e janelas conservan sus accesos independientes.

La migración `V34__seed_maintenance_cameras_telephones_it_providers.sql` crea
un prestador externo activo por especialidad solo si todavía no existe uno.
No cambia órdenes ni prestadores anteriores. Los nuevos prestadores no tienen
contacto o WhatsApp configurado: el operador puede cargar los datos reales en
**Catálogos > Prestadores**. El aviso manual de WhatsApp solo se ofrece cuando
el prestador seleccionado está habilitado y tiene número válido.

## Validación operativa pendiente

1. Aplicar V33 (separación de puertas e Internet) y V34 en el ambiente de
   destino, siguiendo la historia Flyway de ese ambiente.
2. Confirmar que aparecen los tres botones y prestadores por separado.
3. Crear una orden desde cada acceso y comprobar el prestador preseleccionado.
4. Completar contacto y WhatsApp de cada prestador si corresponde; verificar
   la vista previa y el número antes de enviar manualmente.

Las pruebas automatizadas cubren migración, códigos de API y persistencia de
órdenes con prestadores de especialidades distintas. No sustituyen la revisión
visual y de datos en el ambiente real.
