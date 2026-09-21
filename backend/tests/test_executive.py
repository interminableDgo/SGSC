import io
import os
import uuid
from datetime import date, timedelta

import pytest
from fastapi.testclient import TestClient
from openpyxl import load_workbook
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.main import app
from app.database import engine, get_db
from app.security import hasher, issue_token, now
from app.services.executive_service import month_series, where_clause
from app.routers.executive import NewRequest


def test_months_zero_fill_and_year_boundary():
    result=month_series([{'mes':'2026-01','recibidas':2,'resueltas':1}],date(2026,2,1))
    assert len(result)==12
    assert result[0]['mes']=='2025-03'
    assert result[-2]['recibidas']==2
    assert result[-1]['recibidas']==0


def test_scope_always_applied_and_parameterized():
    where, params=where_clause({'entidad_id':7},{'municipio_id':12,'dependencia_id':3})
    assert 'm.entidad_id=:entidad_id' in where
    assert params=={'entidad_id':7,'municipio_id':12,'dependencia_id':3}


def test_blank_request_rejected():
    with pytest.raises(ValueError):
        NewRequest(nombres=' ',apellidos='A',municipio_id=1,tipo_apoyo_id=1,dependencia_id=1,descripcion='x',idempotencia=uuid.uuid4())


@pytest.fixture
def live():
    if os.getenv('RUN_DB_TESTS')!='1':
        pytest.skip('Set RUN_DB_TESTS=1 to run transaction-isolated MySQL tests.')
    connection=engine.connect()
    transaction=connection.begin()
    connection.exec_driver_sql('START TRANSACTION')
    db=Session(bind=connection,join_transaction_mode='create_savepoint')
    address=f'codex-test-{uuid.uuid4().hex}@example.com'
    password='Una frase de prueba segura 2026'
    uid=db.execute(text('INSERT INTO usuario (nombres,apellidos,correo,password_hash) VALUES (:n,:a,:e,:p)'),
      {'n':'Prueba temporal','a':'Transacción','e':address,'p':hasher.hash(password)}).lastrowid
    eid=db.execute(text("SELECT entidad_id FROM cat_entidad_federativa WHERE clave_inegi='19'")).scalar_one()
    rid=db.execute(text("SELECT rol_id FROM cat_rol WHERE clave='EJECUTIVO'")).scalar_one()
    db.execute(text('INSERT INTO usuario_rol (usuario_id,rol_id) VALUES (:u,:r)'),{'u':uid,'r':rid})
    db.execute(text('INSERT INTO ejecutivo_acceso (usuario_id,entidad_id) VALUES (:u,:e)'),{'u':uid,'e':eid})
    db.commit()
    def override():
        yield db
    app.dependency_overrides[get_db]=override
    with TestClient(app) as client:
        try:
            yield client,db,uid,address,password,eid
        finally:
            app.dependency_overrides.clear()
            db.close()
            transaction.rollback()
            connection.close()


def sign_in(client,address,password):
    result=client.post('/auth/login',json={'correo':address,'password':password})
    assert result.status_code==200,result.text
    token=result.json()['token']
    return {'Authorization':'Bearer '+token}


def test_comparison_api_auth_validation_and_empty_scope(live):
    client,db,uid,address,password,eid=live
    params={'a_inicio':'2024-02-01','a_fin':'2024-02-29','b_inicio':'2025-02-01','b_fin':'2025-02-28','municipio_id':2147483647}
    assert client.get('/ejecutivo/comparacion',params=params).status_code==401
    headers=sign_in(client,address,password)
    response=client.get('/ejecutivo/comparacion',params=params,headers=headers)
    assert response.status_code==200
    assert response.json()['a']['total']==response.json()['b']['total']==0
    assert response.json()['variacion']['total']['porcentaje']==0
    assert client.get('/ejecutivo/comparacion',params={**params,'b_fin':'2024-01-01'},headers=headers).status_code==422


def test_empty_data_scope_registration_exports_and_logout(live):
    client,db,uid,address,password,eid=live
    assert client.get('/ejecutivo/dashboard').status_code==401
    headers=sign_in(client,address,password)
    initial=client.get('/ejecutivo/dashboard',headers=headers)
    assert initial.status_code==200,initial.text
    before=initial.json()['total']
    cats=client.get('/ejecutivo/catalogos',headers=headers).json()
    data={'nombres':'Beneficiario temporal','apellidos':'Prueba','descripcion':'Prueba aislada, se revierte',
      'municipio_id':cats['municipios'][0]['id'],'tipo_apoyo_id':cats['apoyos'][0]['id'],
      'dependencia_id':cats['dependencias'][0]['id'],'idempotencia':str(uuid.uuid4())}
    created=client.post('/ejecutivo/solicitudes',json=data,headers=headers)
    assert created.status_code==201,created.text
    assert client.post('/ejecutivo/solicitudes',json=data,headers=headers).json()==created.json()
    sid=created.json()['solicitud_id']
    summary=client.get('/ejecutivo/dashboard',headers=headers).json()
    assert summary['total']==before+1
    assert sum(r['total'] for r in summary['municipios'])==summary['total']
    assert sum(r['total'] for r in summary['grupos'])==summary['total']
    filtered=client.get('/ejecutivo/dashboard?municipio_id=2147483647',headers=headers).json()
    assert filtered['total']==0
    assert filtered['regiones']==[]
    assert len(filtered['tendencia'])==12
    assert client.get(f'/ejecutivo/solicitudes/{sid}',headers=headers).json()['nombres']==data['nombres']
    assert client.get('/ejecutivo/solicitudes/2147483647',headers=headers).status_code==404
    assert client.get('/ejecutivo/dashboard?fecha_inicio=2026-12-01&fecha_fin=2026-01-01',headers=headers).status_code==422
    assert client.post('/ejecutivo/solicitudes',json={**data,'municipio_id':2147483647,'idempotencia':str(uuid.uuid4())},headers=headers).status_code==422
    for fmt in ['xlsx','pdf']:
        report=client.get('/ejecutivo/exportar/'+fmt,headers=headers)
        assert report.status_code==200,report.text[:200]
        assert report.content.startswith(b'PK' if fmt=='xlsx' else b'%PDF')
        if fmt=='xlsx':
            book=load_workbook(io.BytesIO(report.content))
            assert book['Solicitudes'].max_row==before+5
    # An account assigned to another entity cannot see or register NL requests.
    other=db.execute(text("INSERT INTO cat_entidad_federativa (clave_inegi,nombre) VALUES ('99','Prueba temporal aislada')")).lastrowid
    db.execute(text('UPDATE ejecutivo_acceso SET entidad_id=:e WHERE usuario_id=:u'),{'e':other,'u':uid})
    db.commit()
    assert client.get(f'/ejecutivo/solicitudes/{sid}',headers=headers).status_code==404
    assert client.get('/ejecutivo/dashboard',headers=headers).json()['total']==0
    assert client.post('/ejecutivo/solicitudes',json={**data,'idempotencia':str(uuid.uuid4())},headers=headers).status_code==422
    assert client.post('/auth/logout',headers=headers).status_code==200
    assert client.get('/auth/me',headers=headers).status_code==401


def test_reset_single_use_expiry_revocation(live):
    client,db,uid,address,password,eid=live
    headers=sign_in(client,address,password)
    token=issue_token(db,uid,'reset',30)
    expired=issue_token(db,uid,'reset',-1)
    db.commit()
    new_password='Otra frase de prueba segura 2026'
    assert client.post('/auth/reset-password',json={'token':expired,'password':new_password}).status_code==400
    body={'token':token,'password':new_password}
    assert client.post('/auth/reset-password',json=body).status_code==200
    assert client.post('/auth/reset-password',json=body).status_code==400
    assert client.get('/auth/me',headers=headers).status_code==401
    assert client.post('/auth/login',json={'correo':address,'password':password}).status_code==401
    assert client.post('/auth/login',json={'correo':address,'password':new_password}).status_code==200


def test_2fa_and_replay(live):
    import pyotp
    from app.security import cipher
    client,db,uid,address,password,eid=live
    secret=pyotp.random_base32()
    db.execute(text('UPDATE ejecutivo_acceso SET totp_secret=:s WHERE usuario_id=:u'),{'s':cipher().encrypt(secret.encode()).decode(),'u':uid})
    db.commit()
    result=client.post('/auth/login',json={'correo':address,'password':password}).json()
    assert result['requires_2fa'] is True
    token=result['token']
    assert client.get('/auth/me',headers={'Authorization':'Bearer '+token}).status_code==401
    body={'token':token,'code':pyotp.TOTP(secret).now()}
    response=client.post('/auth/verify',json=body)
    assert response.status_code==200,response.text
    assert client.post('/auth/verify',json=body).status_code==400


def test_missing_mail_and_inactive_user(live,monkeypatch):
    client,db,uid,address,password,eid=live
    monkeypatch.delenv('SMTP_HOST',raising=False)
    assert client.post('/auth/forgot-password',json={'correo':address}).status_code==503
    db.execute(text('UPDATE usuario SET activo=0 WHERE usuario_id=:u'),{'u':uid})
    db.commit()
    assert client.post('/auth/login',json={'correo':address,'password':password}).status_code==401
