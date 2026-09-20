"""Local administration: no public account-provisioning endpoint."""
import argparse
import getpass
from pathlib import Path

from sqlalchemy import text

from app.database import engine
from app.security import hasher


def migrate():
    sql=(Path(__file__).parent/'migrations/001_ejecutivo.sql').read_text(encoding='utf-8')
    with engine.begin() as db:
        for statement in sql.split(';'):
            if statement.strip():
                db.execute(text(statement))
    print('Migración aditiva aplicada.')


def seed():
    with engine.begin() as db:
        for name in ['Ayuda técnica','Medicamento','Estudios clínicos']:
            db.execute(text('INSERT IGNORE INTO cat_tipo_apoyo (nombre) VALUES (:name)'),{'name':name})
        for name in ['Secretaría de Salud','DIF Nuevo León']:
            db.execute(text('INSERT IGNORE INTO cat_dependencia (nombre) VALUES (:name)'),{'name':name})
    print('Catálogos del wireframe cargados sin reemplazar registros existentes.')


def provision(args):
    with engine.begin() as db:
        entity=db.execute(text('SELECT entidad_id FROM cat_entidad_federativa WHERE clave_inegi=:code AND activo=1'),{'code':args.entidad}).scalar_one()
        uid=db.execute(text('SELECT usuario_id FROM usuario WHERE correo=:email'),{'email':args.correo}).scalar()
        if uid:
            raise SystemExit('La cuenta ya existe. No se modificó.')
        pending=db.execute(text('SELECT password_hash FROM ejecutivo_acceso_solicitud WHERE correo=:email'),{'email':args.correo}).scalar()
        if not pending:
            password=getpass.getpass('Contraseña inicial (15–128 caracteres): ')
            if not 15 <= len(password) <= 128:
                raise SystemExit('Longitud inválida.')
            pending=hasher.hash(password)
        uid=db.execute(text('INSERT INTO usuario (nombres,apellidos,correo,password_hash) VALUES (:n,:a,:e,:p)'),
          {'n':args.nombres,'a':args.apellidos,'e':args.correo,'p':pending}).lastrowid
        role=db.execute(text("SELECT rol_id FROM cat_rol WHERE clave='EJECUTIVO' AND activo=1")).scalar_one()
        db.execute(text('INSERT INTO usuario_rol (usuario_id,rol_id) VALUES (:u,:r)'),{'u':uid,'r':role})
        db.execute(text('INSERT INTO ejecutivo_acceso (usuario_id,entidad_id) VALUES (:u,:e)'),{'u':uid,'e':entity})
        db.execute(text('DELETE FROM ejecutivo_acceso_solicitud WHERE correo=:email'),{'email':args.correo})
    print('Cuenta ejecutiva autorizada.')


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    sub=parser.add_subparsers(dest='command',required=True)
    sub.add_parser('migrate')
    sub.add_parser('seed-wireframe')
    account=sub.add_parser('create-user')
    for key in ['correo','nombres','apellidos']:
        account.add_argument('--'+key,required=True)
    account.add_argument('--entidad',default='19',help='Clave INEGI del estado autorizado')
    args=parser.parse_args()
    if args.command=='migrate': migrate()
    elif args.command=='seed-wireframe': seed()
    else: provision(args)
