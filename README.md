# SIESAS · Ejecutivo

Réplica Flutter del módulo `AppEjecutivi.tsx` de los wireframes, conectada a FastAPI y MySQL. Incluye acceso, recuperación, solicitud de cuenta, verificación TOTP si la cuenta la tiene configurada, perfil, indicadores, filtros, mapa, detalle, registro y exportación Excel/PDF.

## Abrir en esta computadora

Desde la carpeta SGSC, ejecuta `./iniciar.ps1` y abre http://127.0.0.1:5173. El backend atiende en http://127.0.0.1:8000. Ambos procesos escuchan únicamente en esta computadora. Para recompilar: `./iniciar.ps1 -Recompilar`. La ruta local de Flutter está en `tools.local.json`, excluido de Git.

La fuente visual es el wireframe: Mulish, naranja institucional, azul Salud, tarjetas y logotipo de Nuevo León. La maqueta de teléfono se sustituye por una interfaz Flutter adaptable, de hasta 440 píxeles en escritorio y todo el ancho en móvil.

## Datos y alcance

- Los datos provienen de `sgsc_salud` en Aiven mediante TLS, validando CA y nombre de servidor. Las credenciales y el certificado están en archivos locales excluidos de Git.
- Los endpoints ejecutivos comprueban cuenta activa, rol EJECUTIVO y entidad asignada en **cada solicitud**. No aceptan un estado enviado por el cliente.
- Los catálogos iniciales de apoyo y dependencia son los autorizados del wireframe. Los municipios se leen del catálogo existente: actualmente 15. No se inventan los 36 registros demostrativos ni los municipios faltantes.
- El mapa conserva las 51 geometrías del prototipo y advierte que la agrupación visual regional es aproximada. Las cifras y el filtro regional usan las relaciones reales de MySQL.
- El registro crea un beneficiario con los datos capturados y una solicitud Recibida / Media / App Ejecutiva. Guarda autor e historial. La misma clave de reintento no crea duplicados. No se deduplican personas sólo por coincidencia de nombre.
- Los filtros se aplican en el servidor al resumen, barras, tendencia, lista y exportaciones. Las resueltas se cuentan por fecha de cierre; el filtro de periodo delimita fecha de recepción. La tendencia abarca los últimos 12 meses.
- No hay registros de ejemplo permanentes. Las pruebas MySQL crean datos en una transacción exterior y la revierten.

## Estados vacíos

Sin solicitudes: total cero, invitación a registrar la primera y exportación deshabilitada. Sin coincidencias: mensaje específico y botón para limpiar filtros. Sin catálogos requeridos: formulario sin envío. Información opcional ausente: "Sin información". Sin movimientos mensuales: mensaje en lugar de una gráfica ficticia. Error de conexión: mensaje y reintento; nunca se sustituye por cero. Los resultados viejos se ocultan durante la recarga.

## Acceso y correo

La cuenta inicial de Aldo tiene ámbito Nuevo León. La contraseña se establece mediante un enlace de primer acceso de un solo uso. Las sesiones son tokens opacos aleatorios guardados como hash y duran 8 horas; el cliente los mantiene en memoria. Recargar la página requiere iniciar sesión otra vez.

**Pendiente de configuración externa:** SMTP_HOST, SMTP_FROM y credenciales del proveedor de correo. Mientras falten, Recuperar contraseña muestra que el servicio no está disponible; no afirma haber enviado un correo. Al configurarlas, el enlace abre la pantalla Flutter web para cambiar la contraseña, también desde el correo del teléfono. No se configuraron enlaces universales nativos ni un dominio público.

La contraseña admite de 15 a 128 caracteres y se guarda con Argon2. El enlace vence en 30 minutos, es de un solo uso y revoca las sesiones al cambiar la contraseña. La verificación TOTP es real cuando está configurada; no existe un código universal de demostración.

## Verificación realizada

- Pruebas de backend con MySQL real: ámbito estatal, autenticación, TOTP, enlace vencido/reutilizado, revocación de sesión, creación/reintento, agregaciones y exportaciones.
- Pruebas Flutter: acceso y validación, estado vacío, filtros sin resultados, error de conexión, catálogos vacíos y gráficas con datos de prueba.
- Compilación Flutter web. Android/iOS no se han compilado ni probado en dispositivo.

Para una publicación posterior se requiere HTTPS, dominio de recuperación, orígenes CORS explícitos y un usuario MySQL de ejecución con permisos acotados. La configuración local conserva el usuario Aiven proporcionado para esta integración.
