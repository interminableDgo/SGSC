# SIESAS · Ejecutivo

Réplica Flutter del módulo `AppEjecutivi.tsx` de los wireframes, conectada a FastAPI y MySQL. Incluye acceso, recuperación, solicitud de cuenta, verificación TOTP si la cuenta la tiene configurada, perfil, indicadores, filtros, comparación de periodos, detalle, registro y exportación Excel/PDF.

## Abrir en esta computadora

Desde la carpeta SGSC, ejecuta `./iniciar.ps1` y abre http://127.0.0.1:5173. El backend atiende en http://127.0.0.1:8000. Ambos procesos escuchan únicamente en esta computadora. Para recompilar: `./iniciar.ps1 -Recompilar`. La ruta local de Flutter está en `tools.local.json`, excluido de Git.

La fuente visual es el wireframe: Mulish, naranja institucional, azul Salud, tarjetas y logotipo de Nuevo León. La maqueta de teléfono se sustituye por una interfaz Flutter adaptable, de hasta 440 píxeles en escritorio y todo el ancho en móvil.

## Datos y alcance

- La base activa es `siesas-v2` en Aiven, importada de `SSNL-original.sql`. La conexión valida certificado TLS y nombre de servidor. La anterior, `sgsc_salud`, permanece intacta.
- Las 31 tablas originales mantienen su estructura. Cinco tablas auxiliares sostienen acceso por entidad, sesiones/recuperación, solicitudes de cuenta, límites e idempotencia. Se documentan en `backend/migrations/002_ssnl_ejecutivo.sql`.
- Las consultas usan directamente `Tbl_SolicitudesApoyo`, `Tbl_Beneficiarios` y los catálogos SSNL. No hay vistas de equivalencia ni traslado de solicitudes de la base anterior.
- Cada solicitud de API verifica cuenta activa, rol Ejecutivo y entidad asignada. El municipio utilizado es el domicilio del beneficiario y se verifica su coherencia con la entidad.
- El registro tiene tres pasos: beneficiario, solicitante y solicitud. Permite expedientes existentes o nuevos con los datos obligatorios. Asigna estatus Inicio, conserva autoría y evita duplicados por reintentos.
- Los filtros se aplican a resumen, barras, tendencia, comparación, listado y exportaciones. Los periodos se basan en fecha de registro. “Resueltas actualmente” describe el estado actual de cada cohorte, no el mes de resolución.
- Se retiraron regiones, prioridad por solicitud y fecha de cierre porque el esquema original no las respalda. La dependencia se identifica como remitente y la unidad tratante se muestra aparte.
- Se conservaron los expedientes de ejemplo incluidos en SSNL. Las pruebas adicionales se ejecutan en transacciones que se revierten.
- Pendiente de confirmar con el proyecto original: el catálogo o interpretación de `ben_dom_colonia`, que exige un entero. Por ahora se pide la clave del expediente, sin inventar datos.

## Estados vacíos

Sin solicitudes: total cero, invitación a registrar la primera y exportación deshabilitada. Sin coincidencias: mensaje específico y botón para limpiar filtros. Sin catálogos requeridos: formulario sin envío. Información opcional ausente: "Sin información". Sin movimientos mensuales: mensaje en lugar de una gráfica ficticia. Error de conexión: mensaje y reintento; nunca se sustituye por cero. Los resultados viejos se ocultan durante la recarga.

## Acceso y correo

La cuenta inicial de Aldo tiene ámbito Nuevo León. Se conservó el hash de su contraseña actual al crear su cuenta en SSNL. Las sesiones son tokens opacos aleatorios guardados como hash y duran 8 horas; el cliente los mantiene en memoria. Recargar la página requiere iniciar sesión otra vez.

El envío SMTP está configurado en el archivo local excluido de Git. Se conservó y se verificó su autenticación durante el cambio a SSNL. Los enlaces apuntan al servidor local de esta computadora; para abrirlos desde otro dispositivo hace falta una dirección accesible y configurar RESET_URL. No se configuró un dominio público.

La contraseña admite de 15 a 128 caracteres y se guarda con Argon2. El enlace vence en 30 minutos, es de un solo uso y revoca las sesiones al cambiar la contraseña. La verificación TOTP es real cuando está configurada; no existe un código universal de demostración.

## Verificación realizada

- Pruebas de backend con MySQL real: ámbito estatal, autenticación, TOTP, enlace vencido/reutilizado, revocación de sesión, creación/reintento, agregaciones y exportaciones.
- Pruebas Flutter: acceso y validación, estado vacío, filtros sin resultados, error de conexión, catálogos vacíos y gráficas con datos de prueba.
- Compilación Flutter web. Android/iOS no se han compilado ni probado en dispositivo.

Para una publicación posterior se requiere HTTPS, dominio de recuperación, orígenes CORS explícitos y un usuario MySQL de ejecución con permisos acotados. La configuración local conserva el usuario Aiven proporcionado para esta integración.
