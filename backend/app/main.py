from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import catalogos, dashboard, health, solicitudes, indicadores

app = FastAPI(
    title="SGSC Salud API",
    version="0.1.0",
    description="Backend FastAPI para la Vista Ejecutiva del SGSC.",
)

# Desarrollo local:
# - Flutter mobile no necesita CORS.
# - Flutter web sí.
# En producción se deben reemplazar los orígenes "*" por dominios permitidos.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(catalogos.router)
app.include_router(solicitudes.router)
app.include_router(dashboard.router)
app.include_router(indicadores.router)


@app.get("/")
def root():
    return {
        "proyecto": "SGSC Salud",
        "api": "FastAPI",
        "estado": "online",
        "docs": "/docs",
    }
