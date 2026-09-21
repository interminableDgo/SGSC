from datetime import date

from fastapi import HTTPException, Query
from sqlalchemy import text

JOINS = ''' FROM solicitud_apoyo sa
 JOIN beneficiario b ON b.beneficiario_id=sa.beneficiario_id
 JOIN cat_municipio m ON m.municipio_id=COALESCE(sa.municipio_id,b.municipio_domicilio_id)
 LEFT JOIN cat_region r ON r.region_id=m.region_id
 JOIN cat_tipo_apoyo ta ON ta.tipo_apoyo_id=sa.tipo_apoyo_id
 LEFT JOIN cat_dependencia d ON d.dependencia_id=sa.dependencia_id
 LEFT JOIN cat_grupo_vulnerable g ON g.grupo_vulnerable_id=b.grupo_vulnerable_id
 JOIN cat_estatus_solicitud es ON es.estatus_id=sa.estatus_id'''

FILTER_COLUMNS = {'municipio_id':'m.municipio_id', 'region_id':'m.region_id',
 'tipo_apoyo_id':'sa.tipo_apoyo_id', 'dependencia_id':'sa.dependencia_id',
 'grupo_vulnerable_id':'b.grupo_vulnerable_id', 'estatus_id':'sa.estatus_id'}


def filters(municipio_id: int | None = Query(None, gt=0), region_id: int | None = Query(None, gt=0),
    tipo_apoyo_id: int | None = Query(None, gt=0), dependencia_id: int | None = Query(None, gt=0),
    grupo_vulnerable_id: int | None = Query(None, gt=0), estatus_id: int | None = Query(None, gt=0),
    fecha_inicio: date | None = None, fecha_fin: date | None = None):
    if fecha_inicio and fecha_fin and fecha_inicio > fecha_fin:
        raise HTTPException(422, 'La fecha inicial debe ser anterior a la final.')
    return {k:v for k,v in locals().items() if v is not None}


def where_clause(user, selected):
    clauses = ['m.entidad_id=:entidad_id']
    params = {'entidad_id': user['entidad_id']}
    for key, column in FILTER_COLUMNS.items():
        if key in selected:
            clauses.append(f'{column}=:{key}')
            params[key] = selected[key]
    if selected.get('fecha_inicio'):
        clauses.append('sa.fecha_recepcion>=:fecha_inicio')
        params['fecha_inicio'] = selected['fecha_inicio']
    if selected.get('fecha_fin'):
        clauses.append('sa.fecha_recepcion<DATE_ADD(:fecha_fin, INTERVAL 1 DAY)')
        params['fecha_fin'] = selected['fecha_fin']
    return ' WHERE ' + ' AND '.join(clauses), params


def query_rows(db, sql, params):
    return [dict(r) for r in db.execute(text(sql), params).mappings()]


def groups(db, user, selected):
    where, params = where_clause(user, selected)
    result = {}
    for key, column, label in [
        ('municipios','m.municipio_id','m.nombre'), ('regiones','r.region_id','r.nombre'),
        ('apoyos','ta.tipo_apoyo_id','ta.nombre'), ('dependencias','d.dependencia_id','d.nombre'),
        ('grupos','g.grupo_vulnerable_id','g.nombre')]:
        result[key] = query_rows(db, f'''SELECT {column} AS id, COALESCE({label},'Sin información') AS nombre,
          COUNT(*) AS total {JOINS} {where} GROUP BY {column},{label} ORDER BY total DESC,nombre''', params)
    return result


def month_series(rows, today=None):
    today = today or date.today()
    start = today.year * 12 + today.month - 1 - 11
    indexed = {r['mes']: r for r in rows}
    result=[]
    for number in range(start, start+12):
        year, month = divmod(number, 12)
        key=f'{year:04d}-{month+1:02d}'
        result.append({'mes':key, 'recibidas':0, 'resueltas':0, **indexed.get(key,{})})
    return result


def dashboard(db, user, selected):
    where, params = where_clause(user, selected)
    totals = query_rows(db, f'''SELECT COUNT(*) AS total, COALESCE(SUM(es.es_resuelto=1),0) AS resueltas,
      COALESCE(SUM(es.es_cerrado=0),0) AS activas {JOINS} {where}''', params)[0]
    series=query_rows(db, f'''SELECT mes, SUM(recibidas) AS recibidas, SUM(resueltas) AS resueltas FROM (
      SELECT DATE_FORMAT(sa.fecha_recepcion,'%Y-%m') AS mes, COUNT(*) AS recibidas, 0 AS resueltas
      {JOINS} {where} GROUP BY mes
      UNION ALL
      SELECT DATE_FORMAT(sa.fecha_cierre,'%Y-%m') AS mes, 0 AS recibidas, COUNT(*) AS resueltas
      {JOINS} {where} AND es.es_resuelto=1 AND sa.fecha_cierre IS NOT NULL GROUP BY mes
      ) series GROUP BY mes ORDER BY mes''', params)
    demo = db.execute(text('SELECT COUNT(*) '+JOINS+where+" AND sa.folio LIKE 'DEMO-COMP-%'"),params).scalar_one()
    return {**totals, **groups(db,user,selected), 'tendencia': month_series(series), 'datos_demo': demo}


def compare_periods(db, user, selected, a_inicio, a_fin, b_inicio, b_fin):
    if a_inicio > a_fin or b_inicio > b_fin:
        raise HTTPException(422, 'La fecha inicial debe ser anterior a la final.')
    periods = []
    for start, end in [(a_inicio, a_fin), (b_inicio, b_fin)]:
        where, params = where_clause(user, {**selected, 'fecha_inicio': start, 'fecha_fin': end})
        values = query_rows(db, '''SELECT COUNT(*) AS total,
          COALESCE(SUM(es.es_cerrado=0),0) AS activas,
          COALESCE(SUM(es.es_resuelto=1),0) AS resueltas,
          COALESCE(SUM(sa.folio LIKE 'DEMO-COMP-%'),0) AS datos_demo '''+JOINS+where, params)[0]
        periods.append({'inicio': start, 'fin': end, **{k:int(v) for k,v in values.items()}})
    changes = {}
    for key in ['total', 'activas', 'resueltas']:
        a, b = periods[0][key], periods[1][key]
        changes[key] = {'diferencia': b-a, 'porcentaje': round((b-a)*100/a, 1) if a else (0 if b == 0 else None)}
    return {'a': periods[0], 'b': periods[1], 'variacion': changes}


ROW_SELECT = '''SELECT sa.solicitud_id, sa.folio, sa.fecha_recepcion, sa.fecha_cierre,
 m.nombre AS municipio, ta.nombre AS tipo_apoyo, COALESCE(d.nombre,'Sin información') AS dependencia,
 es.nombre AS estatus, COALESCE(g.nombre,'Sin información') AS grupo_vulnerable,
 COALESCE(r.nombre,'Sin información') AS region'''


def list_rows(db,user,selected,limit=10,offset=0):
    where, params=where_clause(user,selected)
    total=db.execute(text('SELECT COUNT(*) '+JOINS+where),params).scalar_one()
    rows=query_rows(db, ROW_SELECT+JOINS+where+' ORDER BY sa.fecha_recepcion DESC, sa.solicitud_id DESC LIMIT :limit OFFSET :offset',
      {**params,'limit':limit,'offset':offset})
    return {'total':total, 'items':rows}
