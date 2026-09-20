from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db

router = APIRouter(
    prefix="/indicadores",
    tags=["Indicadores"],
)


@router.get("/resumen")
def resumen_indicadores(
    fecha_inicio: Optional[date] = None,
    fecha_fin: Optional[date] = None,
    municipio_id: Optional[int] = None,
    prioridad_id: Optional[int] = None,
    estatus_id: Optional[int] = None,
    tipo_apoyo_id: Optional[int] = None,
    dependencia_id: Optional[int] = None,
    canal_recepcion_id: Optional[int] = None,
    db: Session = Depends(get_db),
):
    condiciones = []
    parametros = {}

    if fecha_inicio:
        condiciones.append(
            "sa.fecha_recepcion >= :fecha_inicio"
        )
        parametros["fecha_inicio"] = fecha_inicio

    if fecha_fin:
        condiciones.append(
            "sa.fecha_recepcion < DATE_ADD(:fecha_fin, INTERVAL 1 DAY)"
        )
        parametros["fecha_fin"] = fecha_fin

    if municipio_id:
        condiciones.append(
            """
            COALESCE(
                sa.municipio_id,
                b.municipio_domicilio_id
            ) = :municipio_id
            """
        )
        parametros["municipio_id"] = municipio_id

    if prioridad_id:
        condiciones.append(
            "sa.prioridad_id = :prioridad_id"
        )
        parametros["prioridad_id"] = prioridad_id

    if estatus_id:
        condiciones.append(
            "sa.estatus_id = :estatus_id"
        )
        parametros["estatus_id"] = estatus_id

    if tipo_apoyo_id:
        condiciones.append(
            "sa.tipo_apoyo_id = :tipo_apoyo_id"
        )
        parametros["tipo_apoyo_id"] = tipo_apoyo_id

    if dependencia_id:
        condiciones.append(
            "sa.dependencia_id = :dependencia_id"
        )
        parametros["dependencia_id"] = dependencia_id

    if canal_recepcion_id:
        condiciones.append(
            "sa.canal_recepcion_id = :canal_recepcion_id"
        )
        parametros["canal_recepcion_id"] = canal_recepcion_id

    where_sql = ""

    if condiciones:
        where_sql = "WHERE " + " AND ".join(condiciones)

    consulta = text(
        f"""
        SELECT
            COUNT(*) AS total_solicitudes,

            COALESCE(
                SUM(
                    CASE
                        WHEN es.es_cerrado = 0
                        THEN 1
                        ELSE 0
                    END
                ),
                0
            ) AS solicitudes_activas,

            COALESCE(
                SUM(
                    CASE
                        WHEN es.es_resuelto = 1
                        THEN 1
                        ELSE 0
                    END
                ),
                0
            ) AS solicitudes_resueltas,

            COALESCE(
                SUM(
                    CASE
                        WHEN sa.riesgo_inmediato = 1
                         AND es.es_cerrado = 0
                        THEN 1
                        ELSE 0
                    END
                ),
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
                        THEN 1
                        ELSE 0
                    END
                )
                /
                NULLIF(
                    SUM(
                        CASE
                            WHEN es.es_resuelto = 1
                             AND sa.fecha_cierre IS NOT NULL
                            THEN 1
                            ELSE 0
                        END
                    ),
                    0
                ),
                2
            ) AS cumplimiento_sla_pct

        FROM solicitud_apoyo sa

        INNER JOIN beneficiario b
            ON b.beneficiario_id = sa.beneficiario_id

        INNER JOIN cat_estatus_solicitud es
            ON es.estatus_id = sa.estatus_id

        INNER JOIN cat_prioridad pr
            ON pr.prioridad_id = sa.prioridad_id

        {where_sql}
        """
    )

    resultado = db.execute(
        consulta,
        parametros,
    ).mappings().first()

    return dict(resultado)