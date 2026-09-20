# SGSC Salud - FastAPI

Backend inicial para la Vista Ejecutiva.

## 1. Crear entorno virtual

Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

macOS/Linux:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

## 2. Instalar dependencias

```bash
pip install -r requirements.txt
```

## 3. Configurar MySQL

Copia `.env.example` como `.env` y coloca tu contraseña:

```env
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=sgsc_salud
DB_USER=root
DB_PASSWORD=TU_PASSWORD
```

La base `sgsc_salud` debe haberse creado previamente con el SQL del proyecto.

## 4. Ejecutar FastAPI

Desde la carpeta `backend`:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Abrir:

- API: http://127.0.0.1:8000
- Swagger: http://127.0.0.1:8000/docs
- Health: http://127.0.0.1:8000/health
- MySQL health: http://127.0.0.1:8000/health/db

## Endpoints iniciales

- `GET /health`
- `GET /health/db`
- `GET /catalogos/prioridades`
- `GET /catalogos/estatus`
- `GET /catalogos/municipios`
- `GET /catalogos/tipos-apoyo`
- `GET /catalogos/dependencias`
- `GET /catalogos/canales`
- `GET /solicitudes`
- `GET /solicitudes/{id}`
- `GET /dashboard/resumen`
- `GET /dashboard/municipios`
- `GET /dashboard/estatus`
- `GET /dashboard/prioridades`

Los endpoints de registro (`POST`) se agregan después, cuando se definan los datos iniciales y las reglas finales del formulario.
