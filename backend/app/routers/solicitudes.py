from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db

router = APIRouter(prefix="/solicitudes", tags=["Solicitudes"])


@router.get("")
def listar_solicitudes(
    municipio_id: Optional[int] = None,
    tipo_apoyo_id: Optional[int] = None,
    prioridad_id: Optional[int] = None,
    estatus_id: Optional[int] = None,
    fecha_inicio: Optional[date] = None,
    fecha_fin: Optional[date] = None,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    where = []
    params = {
        "municipio_id": municipio_id,
        "tipo_apoyo_id": tipo_apoyo_id,
        "prioridad_id": prioridad_id,
        "estatus_id": estatus_id,
        "fecha_inicio": fecha_inicio,
        "fecha_fin": fecha_fin,
        "limit": limit,
        "offset": offset,
    }

    if municipio_id is not None:
        where.append(
            "COALESCE(sa.municipio_id, b.municipio_domicilio_id) = :municipio_id"
        )

    if tipo_apoyo_id is not None:
        where.append("sa.tipo_apoyo_id = :tipo_apoyo_id")

    if prioridad_id is not None:
        where.append("sa.prioridad_id = :prioridad_id")

    if estatus_id is not None:
        where.append("sa.estatus_id = :estatus_id")

    if fecha_inicio is not None:
        where.append("sa.fecha_recepcion >= :fecha_inicio")

    if fecha_fin is not None:
        where.append(
            "sa.fecha_recepcion < DATE_ADD(:fecha_fin, INTERVAL 1 DAY)"
        )

    where_sql = ""
    if where:
        where_sql = "WHERE " + " AND ".join(where)

    sql = text(
        f"""
        SELECT
            sa.solicitud_id,
            sa.folio,
            sa.fecha_recepcion,
            sa.fecha_evaluacion,
            sa.fecha_cierre,

            b.beneficiario_id,
            b.nombres AS beneficiario_nombres,
            b.apellidos AS beneficiario_apellidos,

            s.solicitante_id,
            s.nombres AS solicitante_nombres,
            s.apellidos AS solicitante_apellidos,

            m.municipio_id,
            m.nombre AS municipio,

            c.colonia_id,
            c.nombre AS colonia,

            r.region_id,
            r.nombre AS region,

            ta.tipo_apoyo_id,
            ta.nombre AS tipo_apoyo,

            d.dependencia_id,
            d.nombre AS dependencia,

            pr.prioridad_id,
            pr.nombre AS prioridad,
            pr.sla_objetivo_dias,

            sa.riesgo_inmediato,

            es.estatus_id,
            es.nombre AS estatus,
            es.es_cerrado,
            es.es_resuelto,

            cr.canal_recepcion_id,
            cr.nombre AS canal_recepcion,

            ut.unidad_tratante_id,
            ut.nombre AS unidad_tratante,

            u.usuario_id AS responsable_usuario_id,
            CONCAT_WS(' ', u.nombres, u.apellidos) AS responsable,

            CASE
                WHEN es.es_cerrado = 1
                     AND sa.fecha_cierre IS NOT NULL
                THEN TIMESTAMPDIFF(
                    DAY,
                    sa.fecha_recepcion,
                    sa.fecha_cierre
                )
                ELSE TIMESTAMPDIFF(
                    DAY,
                    sa.fecha_recepcion,
                    NOW()
                )
            END AS dias_transcurridos,

            CASE
                WHEN es.es_resuelto = 1
                     AND sa.fecha_cierre IS NOT NULL
                THEN
                    CASE
                        WHEN TIMESTAMPDIFF(
                            DAY,
                            sa.fecha_recepcion,
                            sa.fecha_cierre
                        ) <= pr.sla_objetivo_dias
                        THEN 1
                        ELSE 0
                    END
                ELSE NULL
            END AS sla_cumplido

        FROM solicitud_apoyo sa

        INNER JOIN beneficiario b
            ON b.beneficiario_id = sa.beneficiario_id

        LEFT JOIN solicitante s
            ON s.solicitante_id = sa.solicitante_id

        LEFT JOIN cat_municipio m
            ON m.municipio_id =
               COALESCE(sa.municipio_id, b.municipio_domicilio_id)

        LEFT JOIN cat_colonia c
            ON c.colonia_id =
               COALESCE(sa.colonia_id, b.colonia_id)

        LEFT JOIN cat_region r
            ON r.region_id = m.region_id

        INNER JOIN cat_tipo_apoyo ta
            ON ta.tipo_apoyo_id = sa.tipo_apoyo_id

        LEFT JOIN cat_dependencia d
            ON d.dependencia_id = sa.dependencia_id

        INNER JOIN cat_prioridad pr
            ON pr.prioridad_id = sa.prioridad_id

        INNER JOIN cat_estatus_solicitud es
            ON es.estatus_id = sa.estatus_id

        LEFT JOIN cat_canal_recepcion cr
            ON cr.canal_recepcion_id = sa.canal_recepcion_id

        LEFT JOIN cat_unidad_tratante ut
            ON ut.unidad_tratante_id = sa.unidad_tratante_id

        LEFT JOIN usuario u
            ON u.usuario_id = sa.responsable_usuario_id

        {where_sql}

        ORDER BY sa.fecha_recepcion DESC
        LIMIT :limit
        OFFSET :offset
        """
    )

    result = db.execute(sql, params)
    return [dict(row) for row in result.mappings().all()]


@router.get("/{solicitud_id}")
def obtener_solicitud(
    solicitud_id: int,
    db: Session = Depends(get_db),
):
    result = db.execute(
        text("""
            SELECT
                sa.*,
                b.nombres AS beneficiario_nombres,
                b.apellidos AS beneficiario_apellidos,
                b.curp,
                s.nombres AS solicitante_nombres,
                s.apellidos AS solicitante_apellidos,
                m.nombre AS municipio,
                c.nombre AS colonia,
                ta.nombre AS tipo_apoyo,
                pr.nombre AS prioridad,
                es.nombre AS estatus
            FROM solicitud_apoyo sa
            INNER JOIN beneficiario b
                ON b.beneficiario_id = sa.beneficiario_id
            LEFT JOIN solicitante s
                ON s.solicitante_id = sa.solicitante_id
            LEFT JOIN cat_municipio m
                ON m.municipio_id =
                   COALESCE(sa.municipio_id, b.municipio_domicilio_id)
            LEFT JOIN cat_colonia c
                ON c.colonia_id =
                   COALESCE(sa.colonia_id, b.colonia_id)
            INNER JOIN cat_tipo_apoyo ta
                ON ta.tipo_apoyo_id = sa.tipo_apoyo_id
            INNER JOIN cat_prioridad pr
                ON pr.prioridad_id = sa.prioridad_id
            INNER JOIN cat_estatus_solicitud es
                ON es.estatus_id = sa.estatus_id
            WHERE sa.solicitud_id = :solicitud_id
        """),
        {"solicitud_id": solicitud_id},
    ).mappings().first()

    if result is None:
        return {"detail": "Solicitud no encontrada"}

    return dict(result)
