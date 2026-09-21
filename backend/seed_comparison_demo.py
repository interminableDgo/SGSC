"""Add identifiable synthetic requests; repeat execution does not duplicate folios."""
from datetime import datetime, timedelta
from sqlalchemy import text
from app.database import engine


def seed():
    inserted = 0
    with engine.begin() as db:
        eid = db.execute(text("SELECT entidad_id FROM cat_entidad_federativa WHERE clave_inegi='19'")).scalar_one()
        municipalities = list(db.execute(text('SELECT municipio_id FROM cat_municipio WHERE entidad_id=:e AND activo=1 ORDER BY municipio_id'), {'e':eid}).scalars())
        def ids(table, pk):
            return list(db.execute(text(f'SELECT {pk} FROM {table} WHERE activo=1 ORDER BY {pk}')).scalars())
        supports = ids('cat_tipo_apoyo','tipo_apoyo_id')
        departments = ids('cat_dependencia','dependencia_id')
        groups = ids('cat_grupo_vulnerable','grupo_vulnerable_id') or [None]
        statuses = dict(db.execute(text('SELECT clave,estatus_id FROM cat_estatus_solicitud WHERE activo=1')).all())
        priority = db.execute(text("SELECT prioridad_id FROM cat_prioridad WHERE clave='MEDIA'")).scalar_one()
        channel = db.execute(text("SELECT canal_recepcion_id FROM cat_canal_recepcion WHERE clave='APP_EJECUTIVA'")).scalar_one()
        assert municipalities and supports and departments
        for year in [2024,2025,2026]:
            for month in range(1,13 if year < 2026 else 9):
                count = 8 + (year-2024)*4 + month % 5
                for index in range(count):
                    folio = f'DEMO-COMP-{year}{month:02d}-{index+1:03d}'
                    if db.execute(text('SELECT solicitud_id FROM solicitud_apoyo WHERE folio=:f'), {'f':folio}).scalar():
                        continue
                    municipality = municipalities[(month+index)%len(municipalities)]
                    bid = db.execute(text('''INSERT INTO beneficiario (nombres,apellidos,municipio_domicilio_id,grupo_vulnerable_id)
                        VALUES (:n,'FICTICIO - comparacion',:m,:g)'''),
                        {'n':f'DEMO {year}-{month:02d}-{index+1:03d}','m':municipality,'g':groups[index%len(groups)]}).lastrowid
                    status = ['RECIBIDA','EN_ATENCION','RESUELTA','RESUELTA','CANCELADA'][(index+year)%5]
                    received = datetime(year,month,1+index%22,10,0)
                    closed = received + timedelta(days=3) if status in ['RESUELTA','CANCELADA'] else None
                    db.execute(text('''INSERT INTO solicitud_apoyo
                        (folio,beneficiario_id,municipio_id,tipo_apoyo_id,dependencia_id,descripcion,observaciones,
                         estatus_id,prioridad_id,canal_recepcion_id,fecha_recepcion,fecha_cierre)
                        VALUES (:f,:b,:m,:t,:d,:description,:description,:s,:p,:c,:r,:closed)'''),
                        {'f':folio,'b':bid,'m':municipality,'t':supports[index%len(supports)],
                         'd':departments[(index+month)%len(departments)],
                         'description':'DATO FICTICIO para probar comparaciones. Lote DEMO-COMP-v1. No representa personas ni atenciones reales.',
                         's':statuses[status],'p':priority,'c':channel,'r':received,'closed':closed})
                    inserted += 1
    print(f'Solicitudes ficticias insertadas: {inserted}. Lote DEMO-COMP-v1; enero 2024 a agosto 2026.')


if __name__ == '__main__':
    seed()
