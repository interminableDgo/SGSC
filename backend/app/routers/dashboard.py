from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/resumen")
def resumen(db: Session = Depends(get_db)):
    result = db.execute(
        text("""
            SELECT
                COUNT(*) AS total_solicitudes,

                COALESCE(
                    SUM(CASE
                        WHEN es.es_cerrado = 0
                        THEN 1 ELSE 0
                    END),
                    0
                ) AS solicitudes_activas,

                COALESCE(
                    SUM(CASE
                        WHEN es.es_resuelto = 1
                        THEN 1 ELSE 0
                    END),
                    0
                ) AS solicitudes_resueltas,

                COALESCE(
                    SUM(CASE
                        WHEN sa.riesgo_inmediato = 1
                         AND es.es_cerrado = 0
                        THEN 1 ELSE 0
                    END),
                    0
                ) AS riesgo_inmediato_abiertos,

                ROUND(
                    AVG(
                        CASE
                            WHEN es.es_resuelto = 1
                             AND sa.fecha_cierre IS NOT NULL
                            THEN TIMESTAMPDIFF(
                                DAY,
                                sa.fecha_recepcion,
                                sa.fecha_cierre
                            )
                            ELSE NULL
                        END
                    ),
                    2
                ) AS promedio_dias_resolucion,

                ROUND(
                    100.0 *
                    SUM(
                        CASE
                            WHEN es.es_resuelto = 1
                             AND sa.fecha_cierre IS NOT NULL
                             AND TIMESTAMPDIFF(
                                DAY,
                                sa.fecha_recepcion,
                                sa.fecha_cierre
                             ) <= pr.sla_objetivo_dias
                            THEN 1 ELSE 0
                        END
                    )
                    /
                    NULLIF(
                        SUM(
                            CASE
                                WHEN es.es_resuelto = 1
                                 AND sa.fecha_cierre IS NOT NULL
                                THEN 1 ELSE 0
                            END
                        ),
                        0
                    ),
                    2
                ) AS cumplimiento_sla_pct

            FROM solicitud_apoyo sa
            INNER JOIN cat_estatus_solicitud es
                ON es.estatus_id = sa.estatus_id
            INNER JOIN cat_prioridad pr
                ON pr.prioridad_id = sa.prioridad_id
        """)
    ).mappings().first()

    return dict(result)


@router.get("/municipios")
def solicitudes_por_municipio(db: Session = Depends(get_db)):
    result = db.execute(
        text("""
            SELECT
                m.municipio_id,
                m.nombre AS municipio,
                COUNT(sa.solicitud_id) AS total_solicitudes
            FROM solicitud_apoyo sa
            INNER JOIN beneficiario b
                ON b.beneficiario_id = sa.beneficiario_id
            INNER JOIN cat_municipio m
                ON m.municipio_id =
                   COALESCE(sa.municipio_id, b.municipio_domicilio_id)
            GROUP BY m.municipio_id, m.nombre
            ORDER BY total_solicitudes DESC
        """)
    )

    return [dict(row) for row in result.mappings().all()]


@router.get("/estatus")
def solicitudes_por_estatus(db: Session = Depends(get_db)):
    result = db.execute(
        text("""
            SELECT
                es.estatus_id,
                es.nombre AS estatus,
                COUNT(sa.solicitud_id) AS total_solicitudes
            FROM cat_estatus_solicitud es
            LEFT JOIN solicitud_apoyo sa
                ON sa.estatus_id = es.estatus_id
            WHERE es.activo = 1
            GROUP BY
                es.estatus_id,
                es.nombre,
                es.orden_visual
            ORDER BY es.orden_visual
        """)
    )

    return [dict(row) for row in result.mappings().all()]


@router.get("/prioridades")
def solicitudes_por_prioridad(db: Session = Depends(get_db)):
    result = db.execute(
        text("""
            SELECT
                pr.prioridad_id,
                pr.nombre AS prioridad,
                pr.sla_objetivo_dias,
                COUNT(sa.solicitud_id) AS total_solicitudes
            FROM cat_prioridad pr
            LEFT JOIN solicitud_apoyo sa
                ON sa.prioridad_id = pr.prioridad_id
            WHERE pr.activo = 1
            GROUP BY
                pr.prioridad_id,
                pr.nombre,
                pr.sla_objetivo_dias,
                pr.orden_visual
            ORDER BY pr.orden_visual
        """)
    )

    return [dict(row) for row in result.mappings().all()]
