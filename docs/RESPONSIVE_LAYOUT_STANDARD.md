# ESTANDAR RESPONSIVE Y ANTI-OVERFLOW

## Objetivo
- Evitar desbordes (`RenderFlex overflow`) en cards, grids, paneles y formularios.
- Mantener comportamiento predecible entre desktop amplio, desktop angosto y ventanas reducidas.

## Reglas base
- No usar `crossAxisCount` fijo en grids densas si el ancho del contenedor puede variar.
- Para grids operativas, calcular columnas con `LayoutBuilder` segun `constraints.maxWidth`.
- Preferir `mainAxisExtent` en grids con contenido vertical conocido.
- Todo texto dentro de cards/celdas debe definir `maxLines` y `overflow`.
- Si el contenido de una celda puede crecer, el detalle debe salir de la celda y mostrarse en un panel lateral, dialogo o vista secundaria.
- No confiar en que el layout desktop siempre tendra ancho completo.

## Parametros recomendados
- `>= 1100 px`: hasta `7` columnas para calendarios mensuales.
- `860-1099 px`: `5` columnas.
- `620-859 px`: `4` columnas.
- `380-619 px`: `2` columnas.
- `< 380 px`: `1` columna.

## Celdas de agenda
- Alto estable con `mainAxisExtent`.
- Mostrar en la celda solo:
  - dia
  - dia de semana
  - contador de items
  - maximo `2` resumenes cortos
- El resumen debe ir con texto truncado.

## Formularios y paneles
- Formularios largos deben vivir en un contenedor que pueda crecer verticalmente.
- En layouts compactos, apilar paneles verticalmente.
- En layouts amplios, usar `Row + Expanded` solo cuando cada panel tenga ancho minimo razonable.

## Checklist antes de cerrar una pantalla
- Probar ancho amplio.
- Probar ancho intermedio.
- Probar ancho compacto.
- Probar textos largos.
- Confirmar que no existan `RenderFlex overflow`.
- Confirmar que todos los `GridView` y `Row` con contenido variable tengan limites de texto.
