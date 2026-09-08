# Manutencao: distribucion del banner

## Cambios
- Se agrupan los botones de creacion bajo `Criar ordem`.
- `Nova ordem` pasa a llamarse `General`; los accesos por especialidad usan nombres cortos, sin el prefijo `Ordem`, como `AA` y `Portas e janelas`.
- `Consultas` contiene `Estado das ordens` y `Alterar dia`.
- `Gestao` contiene `Preventivos` y `Catalogos`.
- Consultas y gestion comparten una fila con dos columnas de igual ancho y 24 px de separacion. Los botones se distribuyen dentro de cada grupo con `Wrap`.
- Se elimina el ovalo `Manutencao` del banner.
- Se conservan los callbacks y las condiciones de habilitacion de los botones. No hay cambios de API.

## Validacion
- `dart format lib/features/maintenance/presentation/maintenance_page.dart`.
- `flutter analyze lib/features/maintenance/presentation/maintenance_page.dart`: sin errores; 9 avisos informativos de APIs deprecadas en el archivo de trabajo.
- No se realizo validacion visual en navegador.

## Alcance del commit
Cambios del banner y esta documentacion. Los ajustes previos de formularios, prestadores y otros modulos quedan pendientes fuera de este commit.
