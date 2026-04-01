# MASSAGES PROVIDER REPORT PDF STANDARD

Fecha: 2026-04-01  
Modulo: `Massagens`  
Frontend base: `lib/features/massages/presentation/massage_booking_page.dart`  
Exportador: `lib/features/massages/application/massage_provider_report_pdf_exporter.dart`

## Objetivo
- Permitir que el operador genere un PDF del `Resumo por prestador`.
- El archivo debe poder:
  - guardarse manualmente
  - compartirse manualmente
  - incluir identidad visual del hotel
  - resultar legible para envio directo al prestador

## Flujo operativo implementado
- El operador abre `Massagens`.
- Dentro de `Resumo por prestador`, selecciona `Ver detalhe`.
- En el modal del prestador dispone de:
  - `Baixar PDF`
  - `Compartilhar PDF`

## Contenido del PDF
- Encabezado con logo del hotel.
- Nombre del hotel.
- Nombre del prestador.
- Titulo del reporte.
- Periodo consultado.
- Estado del prestador.
- Fecha y hora de emision.
- Resumen ejecutivo del periodo:
  - atenciones
  - canceladas
  - pagas
  - pendientes
  - cobrado
  - pendiente
  - total previsto
  - ultima atencion
- Detalle de atenciones por item:
  - cliente
  - fecha
  - hora
  - tratamiento
  - referencia
  - masajista
  - valor
  - estado de pago
  - observaciones de pago si existen
  - motivo de cancelacion si existe

## Criterios visuales actuales
- El PDF usa una jerarquia tipografica estable:
  - titulo principal
  - subtitulo / contexto
  - informacion operativa
- El logo se compone dentro de un recuadro propio:
  - velas visibles dentro del bloque
  - texto institucional debajo
- Los bloques del contenido usan fondos muy leves para sugerir separacion visual sin borde duro.

## Implementacion tecnica
- Generacion con paquete `pdf`.
- Guardado manual con `file_picker`.
- Compartido manual con `share_plus`.
- Fuentes incrustadas para evitar fallback a `Helvetica`:
  - `assets/fonts/Lato-Regular.ttf`
  - `assets/fonts/Lato-Bold.ttf`

## Archivos involucrados
- `lib/features/massages/application/massage_provider_report_pdf_exporter.dart`
- `lib/features/massages/presentation/massage_booking_page.dart`
- `lib/core/feedback/app_share.dart`
- `assets/fonts/Lato-Regular.ttf`
- `assets/fonts/Lato-Bold.ttf`

## Validacion recomendada
```powershell
flutter analyze lib/features/massages/application/massage_provider_report_pdf_exporter.dart
flutter test test/features/massages/application/massage_provider_report_pdf_exporter_test.dart
flutter test test/features/massages/presentation/massage_booking_page_test.dart
```
