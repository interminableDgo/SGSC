from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db

router = APIRouter(prefix="/catalogos", tags=["Catálogos"])


def rows_as_dicts(result):
    return [dict(row) for row in result.mappings().all()]


@router.get("/prioridades")
def prioridades(db: Session = Depends(get_db)):
    result = db.execute(
        text("""
            SELECT
                prioridad_id,
                clave,
                nombre,
                sla_objetivo_dias,
                orden_visual
            FROM cat_prioridad
            WHERE activo = 1
            ORDER BY orden_visual
        """)
    )
    return rows_as_dicts(result)


@router.get("/estatus")
def estatus(db: Session = Depends(get_db)):
    result = db.execute(
        text("""
            SELECT
                estatus_id,
                clave,
                nombre,
                es_cerrado,
                es_resuelto,
                orden_visual
            FROM cat_estatus_solicitud
            WHERE activo = 1
            ORDER BY orden_visual
        """)
    )
    return rows_as_dicts(result)


@router.get("/municipios")
def municipios(db: Session = Depends(get_db)):
    result = db.execute(
        text("""
            SELECT
                m.municipio_id,
                m.clave_inegi,
                m.nombre,
                r.region_id,
                r.nombre AS region
            FROM cat_municipio m
            LEFT JOIN cat_region r
                ON r.region_id = m.region_id
            WHERE m.activo = 1
            ORDER BY m.nombre
        """)
    )
    return rows_as_dicts(result)


@router.get("/tipos-apoyo")
def tipos_apoyo(db: Session = Depends(get_db)):
    result = db.execute(
        text("""
            SELECT
                tipo_apoyo_id,
                nombre,
                descripcion
            FROM cat_tipo_apoyo
            WHERE activo = 1
            ORDER BY nombre
        """)
    )
    return rows_as_dicts(result)


@router.get("/dependencias")
def dependencias(db: Session = Depends(get_db)):
    result = db.execute(
        text("""
            SELECT
                dependencia_id,
                nombre,
                siglas
            FROM cat_dependencia
            WHERE activo = 1
            ORDER BY nombre
        """)
    )
    return rows_as_dicts(result)


@router.get("/canales")
def canales(db: Session = Depends(get_db)):
    result = db.execute(
        text("""
            SELECT
                canal_recepcion_id,
                clave,
                nombre
            FROM cat_canal_recepcion
            WHERE activo = 1
            ORDER BY nombre
        """)
    )
    return rows_as_dicts(result)
