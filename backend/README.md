# Backend SIESAS Ejecutivo

Python 3.12+, FastAPI, SQLAlchemy, PyMySQL y MySQL.

## Instalación y ejecución

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Antes de migrar, completar `.env`: host, puerto, usuario y contraseña de Aiven, DB_NAME=sgsc_salud, DB_SSL=true y DB_SSL_CA con la ruta de ca.pem. La conexión valida el certificado y nombre de servidor. No ejecutar `sgsc_salud_desde_cero.sql` sobre una base con datos: contiene DROP DATABASE. La migración nueva es aditiva.

## Administración local

- `python manage.py seed-wireframe`: carga los tipos de apoyo y dependencias del prototipo sin reemplazar filas existentes.
- `python manage.py create-user --correo persona@dominio.mx --nombres Nombre --apellidos Apellido --entidad 19`: autoriza la solicitud de acceso pendiente o pide una contraseña por entrada oculta. No modifica una cuenta existente.
- `python manage.py setup-2fa --correo persona@dominio.mx`: vincula un autenticador y exige un código válido antes de activarlo. Requiere AUTH_ENCRYPTION_KEY; conservar esta clave entre reinicios.

## Correo

Configurar SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, SMTP_FROM, SMTP_SSL y RESET_URL. SMTP_SSL=false usa STARTTLS; true usa TLS directo. No se envían correos sin configuración. RESET_URL debe ser la dirección HTTPS pública de Flutter web en producción.

La respuesta de recuperación es genérica y no revela si existe una cuenta. El enlace vence en 30 minutos y es de un solo uso. La entrega ocurre después de responder, mediante una tarea de FastAPI. Fallas SMTP se registran sin datos personales. Para una operación crítica se debe sustituir esta tarea por una cola durable con reintentos.

## Rutas

Autenticación: POST /auth/login, /auth/verify, /auth/logout, /auth/request-access, /auth/forgot-password, /auth/reset-password; GET /auth/me.

Datos: GET /ejecutivo/catalogos, /ejecutivo/dashboard; GET y POST /ejecutivo/solicitudes; GET /ejecutivo/solicitudes/{id}; GET /ejecutivo/exportar/xlsx y /ejecutivo/exportar/pdf.

Datos y perfil requieren Authorization: Bearer. Cada consulta verifica cuenta activa, rol EJECUTIVO y entidad asignada. Los routers antiguos permanecen como referencia pero no se publican porque no aplicaban este control.

Filtros compartidos: municipio_id, region_id, tipo_apoyo_id, dependencia_id, grupo_vulnerable_id, estatus_id, fecha_inicio, fecha_fin. Lista: page desde cero, 10 filas por página. Exportación: hasta 10,000 solicitudes, con filtros incluidos. Excel trata valores como texto para evitar fórmulas inyectadas.

## Pruebas

```powershell
.\.venv\Scripts\python.exe -m pytest -q
$env:RUN_DB_TESTS='1'
.\.venv\Scripts\python.exe -m pytest -q
```

Las pruebas de MySQL usan una transacción exterior con savepoints y revierten sus filas temporales. Requieren la migración y los catálogos. No ejecutarlas simultáneamente desde el mismo proceso.

La importación original tenía 26 campos de catálogo mal codificados. Se corrigieron sin cambiar claves ni relaciones. Respaldo reversible: catalog_encoding_backup.local.json, excluido de Git.
