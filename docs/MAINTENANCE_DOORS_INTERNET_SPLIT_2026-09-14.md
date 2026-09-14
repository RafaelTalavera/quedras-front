# Manutenção: Portas e janelas separadas de Internet

Fecha: 2026-09-14. Repositorios: `quadras` (backend) y `quedras-front`.

## Cambio funcional

- **Portas e janelas** usa la nueva especialidad `DOORS_AND_WINDOWS`.
- **Internet** conserva `INTERNET` y tiene su propio botón para crear órdenes.
- Cada acceso preselecciona el prestador de su especialidad. Ambos aparecen
  separados en el catálogo y pueden tener número WhatsApp independiente.
- El backend admite ambos códigos en el contrato de prestadores. La migración
  V33 crea un prestador externo de Portas e janelas solo si aún no existe uno.

## Protección de datos

V33 no modifica ni reclasifica prestadores u órdenes existentes de `INTERNET`.
Algunas órdenes históricas de puertas pudieron haberse creado desde el antiguo
botón que apuntaba a Internet. No hay una marca fiable para identificarlas; si
se requiere reclasificarlas, deberá hacerse una revisión de datos caso por caso.
El prestador nuevo no tiene número WhatsApp ni permiso habilitado por defecto;
hay que configurarlos en el catálogo antes de preparar avisos.

## Comprobación

1. Verificar que aparecen los botones **Portas e janelas** e **Internet**.
2. Crear una orden desde cada uno y comprobar que se preselecciona un
   prestador diferente y que las órdenes conservan el prestador elegido.
3. Comprobar que el catálogo muestra ambas especialidades sin renombrar
   Internet como Portas e janelas.
4. Configurar WhatsApp de cada prestador por separado y comprobar el aviso
   manual con el número correspondiente.

Las pruebas automatizadas verifican la migración V33 y los códigos del
contrato Flutter. Falta una prueba manual con los datos y la sesión reales.
