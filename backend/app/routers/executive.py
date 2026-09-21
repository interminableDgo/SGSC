import io
import uuid
from datetime import date, datetime, timezone
from html import escape
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill
from pydantic import BaseModel, Field, field_validator
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.security import current_user, now
from app.services import executive_service as svc

router=APIRouter(prefix='/ejecutivo',tags=['Ejecutivo'])


@router.get('/catalogos')
def catalogs(user=Depends(current_user),db:Session=Depends(get_db)):
    result={}
    for name, table, pk in [
      ('apoyos','cat_tipo_apoyo','tipo_apoyo_id'),('dependencias','cat_dependencia','dependencia_id'),
      ('grupos','cat_grupo_vulnerable','grupo_vulnerable_id'),('estatus','cat_estatus_solicitud','estatus_id')]:
        result[name]=svc.query_rows(db,f'SELECT {pk} AS id,nombre FROM {table} WHERE activo=1 ORDER BY nombre',{})
    result['municipios']=svc.query_rows(db,'''SELECT municipio_id AS id,nombre,clave_inegi,region_id
      FROM cat_municipio WHERE activo=1 AND entidad_id=:eid ORDER BY nombre''',{'eid':user['entidad_id']})
    result['regiones']=svc.query_rows(db,'''SELECT DISTINCT r.region_id AS id,r.nombre FROM cat_region r
      JOIN cat_municipio m ON m.region_id=r.region_id WHERE r.activo=1 AND m.entidad_id=:eid ORDER BY r.nombre''',{'eid':user['entidad_id']})
    return result


@router.get('/dashboard')
def dashboard(selected=Depends(svc.filters),user=Depends(current_user),db:Session=Depends(get_db)):
    return svc.dashboard(db,user,selected)


@router.get('/comparacion')
def comparison(a_inicio:date, a_fin:date, b_inicio:date, b_fin:date,
    selected=Depends(svc.filters),user=Depends(current_user),db:Session=Depends(get_db)):
    return svc.compare_periods(db,user,selected,a_inicio,a_fin,b_inicio,b_fin)


@router.get('/solicitudes')
def requests(selected=Depends(svc.filters),page:int=Query(0,ge=0),user=Depends(current_user),db:Session=Depends(get_db)):
    return svc.list_rows(db,user,selected,10,page*10)


@router.get('/solicitudes/{sid}')
def detail(sid:int,user=Depends(current_user),db:Session=Depends(get_db)):
    where,params=svc.where_clause(user,{})
    rows=svc.query_rows(db,svc.ROW_SELECT+''', sa.descripcion,sa.observaciones,
      b.nombres,b.apellidos,pr.nombre AS prioridad'''+svc.JOINS+
      ' JOIN cat_prioridad pr ON pr.prioridad_id=sa.prioridad_id'+where+' AND sa.solicitud_id=:sid',{**params,'sid':sid})
    if not rows:
        raise HTTPException(404,'Solicitud no encontrada.')
    return rows[0]


class NewRequest(BaseModel):
    nombres:str=Field(min_length=1,max_length=150)
    apellidos:str=Field(min_length=1,max_length=150)
    municipio_id:int=Field(gt=0)
    tipo_apoyo_id:int=Field(gt=0)
    dependencia_id:int=Field(gt=0)
    grupo_vulnerable_id:int|None=Field(None,gt=0)
    descripcion:str=Field(min_length=1,max_length=5000)
    idempotencia:uuid.UUID

    @field_validator('nombres','apellidos','descripcion')
    @classmethod
    def strip_text(cls,value):
        if not value.strip():
            raise ValueError('Completa este campo.')
        return value.strip()


def existing_request(db,user,key):
    return db.execute(text('''SELECT sa.solicitud_id,sa.folio FROM ejecutivo_registro er
      JOIN solicitud_apoyo sa ON sa.solicitud_id=er.solicitud_id
      WHERE er.usuario_id=:uid AND er.idempotencia=:key'''),{'uid':user['usuario_id'],'key':str(key)}).mappings().first()


@router.post('/solicitudes',status_code=201)
def create_request(data:NewRequest,user=Depends(current_user),db:Session=Depends(get_db)):
    existing=existing_request(db,user,data.idempotencia)
    if existing:
        return dict(existing)
    valid=db.execute(text('SELECT municipio_id FROM cat_municipio WHERE municipio_id=:id AND entidad_id=:eid AND activo=1'),
      {'id':data.municipio_id,'eid':user['entidad_id']}).scalar()
    if not valid:
        raise HTTPException(422,'Selecciona un municipio de tu estado asignado.')
    for table,pk,value in [('cat_tipo_apoyo','tipo_apoyo_id',data.tipo_apoyo_id),
      ('cat_dependencia','dependencia_id',data.dependencia_id),('cat_grupo_vulnerable','grupo_vulnerable_id',data.grupo_vulnerable_id)]:
        if value is not None and not db.execute(text(f'SELECT {pk} FROM {table} WHERE {pk}=:id AND activo=1'),{'id':value}).scalar():
            raise HTTPException(422,'Una opción seleccionada ya no está disponible. Actualiza los catálogos.')
    defaults={}
    for key,table,pk,code in [('status','cat_estatus_solicitud','estatus_id','RECIBIDA'),
      ('priority','cat_prioridad','prioridad_id','MEDIA'),('channel','cat_canal_recepcion','canal_recepcion_id','APP_EJECUTIVA')]:
        defaults[key]=db.execute(text(f'SELECT {pk} FROM {table} WHERE clave=:code AND activo=1'),{'code':code}).scalar()
    if not all(defaults.values()):
        raise HTTPException(503,'Falta configurar los catálogos de recepción de solicitudes.')
    try:
        bid=db.execute(text('''INSERT INTO beneficiario (nombres,apellidos,municipio_domicilio_id,grupo_vulnerable_id)
          VALUES (:nombres,:apellidos,:municipio_id,:grupo_vulnerable_id)'''),data.model_dump()).lastrowid
        folio='SGSC-'+uuid.uuid4().hex[:24].upper()
        sid=db.execute(text('''INSERT INTO solicitud_apoyo (folio,beneficiario_id,municipio_id,tipo_apoyo_id,
          dependencia_id,descripcion,estatus_id,prioridad_id,canal_recepcion_id)
          VALUES (:folio,:bid,:municipio_id,:tipo_apoyo_id,:dependencia_id,:descripcion,:status,:priority,:channel)'''),
          {**data.model_dump(),**defaults,'folio':folio,'bid':bid}).lastrowid
        db.execute(text('''INSERT INTO ejecutivo_registro (solicitud_id,usuario_id,idempotencia)
          VALUES (:sid,:uid,:key)'''),{'sid':sid,'uid':user['usuario_id'],'key':str(data.idempotencia)})
        db.execute(text('''INSERT INTO solicitud_estatus_historial (solicitud_id,estatus_id,usuario_id,comentario)
          VALUES (:sid,:status,:uid,'Registro desde App Ejecutiva')'''),{'sid':sid,'status':defaults['status'],'uid':user['usuario_id']})
        db.commit()
        return {'solicitud_id':sid,'folio':folio}
    except IntegrityError:
        db.rollback()
        existing=existing_request(db,user,data.idempotencia)
        if existing:
            return dict(existing)
        raise HTTPException(409,'No fue posible registrar la solicitud. Actualiza los catálogos e intenta nuevamente.')


EXPORT_FIELDS=['folio','municipio','tipo_apoyo','dependencia','estatus','region','grupo_vulnerable']
EXPORT_HEADERS=['Folio','Municipio','Tipo de apoyo','Dependencia','Estatus','Región','Grupo vulnerable']


@router.get('/exportar/{format}')
def export(format:Literal['xlsx','pdf'],selected=Depends(svc.filters),user=Depends(current_user),db:Session=Depends(get_db)):
    result=svc.list_rows(db,user,selected,10001,0)
    if result['total']>10000:
        raise HTTPException(422,'El reporte supera 10,000 solicitudes. Aplica filtros para exportar.')
    rows=result['items']
    summary=svc.dashboard(db,user,selected)
    metadata=f"{user['entidad']} · {datetime.now(timezone.utc):%Y-%m-%d %H:%M} UTC · {result['total']} solicitudes"
    cats=catalogs(user,db)
    labels={'municipio_id':('Municipio','municipios'),'region_id':('Región','regiones'),
      'tipo_apoyo_id':('Apoyo','apoyos'),'dependencia_id':('Dependencia','dependencias'),
      'grupo_vulnerable_id':('Grupo','grupos'),'estatus_id':('Estatus','estatus')}
    filter_parts=[]
    for key,value in selected.items():
        if key in labels:
            label,cat=labels[key]
            value=next((r['nombre'] for r in cats[cat] if r['id']==value),str(value))
        else:
            label=key.replace('_',' ').capitalize()
        filter_parts.append(f'{label}: {value}')
    filter_text='; '.join(filter_parts) or 'Sin filtros adicionales'
    stream=io.BytesIO()
    if format=='xlsx':
        book=Workbook()
        sheet=book.active
        sheet.title='Solicitudes'
        sheet.append(['SIESAS · Ejecutivo'])
        sheet.append([metadata])
        sheet.append([filter_text])
        sheet.append(EXPORT_HEADERS)
        for row in rows:
            sheet.append([str(row.get(k) or 'Sin información') for k in EXPORT_FIELDS])
        # Treat every cell as text, including strings beginning with '='.
        for line in sheet:
            for cell in line:
                cell.data_type='s'
        for cell in sheet[4]:
            cell.font=Font(color='FFFFFF',bold=True)
            cell.fill=PatternFill('solid',fgColor='1B2A33')
        sheet.freeze_panes='A5'
        sheet.auto_filter.ref=f'A4:G{max(4,sheet.max_row)}'
        for column in 'ABCDEFG':
            sheet.column_dimensions[column].width=30
        trend=book.create_sheet('Tendencia')
        trend.append(['Mes','Recibidas','Resueltas'])
        for item in summary['tendencia']:
            trend.append([item['mes'],item['recibidas'],item['resueltas']])
        book.save(stream)
        mime='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else:
        styles=getSampleStyleSheet()
        styles['BodyText'].fontSize=8
        document=SimpleDocTemplate(stream,pagesize=landscape(A4),leftMargin=24,rightMargin=24,topMargin=24,bottomMargin=24)
        content=[Paragraph('SIESAS · Ejecutivo',styles['Title']),Paragraph(escape(metadata),styles['BodyText']),
          Paragraph(escape(filter_text),styles['BodyText']),Spacer(1,14)]
        table_rows=[EXPORT_HEADERS]+[[Paragraph(escape(str(r.get(k) or 'Sin información')),styles['BodyText']) for k in EXPORT_FIELDS] for r in rows]
        table=Table(table_rows,colWidths=[120,95,105,125,75,90,180-96],repeatRows=1)
        table.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#1B2A33')),
          ('TEXTCOLOR',(0,0),(-1,0),colors.white),('FONTSIZE',(0,0),(-1,-1),8),
          ('VALIGN',(0,0),(-1,-1),'TOP'),('BOTTOMPADDING',(0,0),(-1,-1),8),
          ('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#F3F3F0')])]))
        content.append(table)
        document.build(content)
        mime='application/pdf'
    return Response(stream.getvalue(),media_type=mime,headers={'Content-Disposition':f'attachment; filename="SIESAS-ejecutivo.{format}"','Cache-Control':'no-store'})
