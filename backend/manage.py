"""Local administration: no public account-provisioning endpoint."""
import argparse
import getpass
from pathlib import Path

from sqlalchemy import text

from app.database import engine
from app.security import hasher


def migrate():
    sql=(Path(__file__).parent/'migrations/002_ssnl_ejecutivo.sql').read_text(encoding='utf-8')
    with engine.begin() as db:
        for statement in sql.split(';'):
            if statement.strip():
                db.execute(text(statement))
    print('Migración aditiva aplicada.')


def seed():
    raise SystemExit('SSNL utiliza sus catálogos originales. No se cargan los catálogos del wireframe.')


def provision(args):
    with engine.begin() as db:
        entity=db.execute(text('SELECT id FROM INEGI_Cat_Entidades WHERE cve_ent=:code'),{'code':args.entidad}).scalar_one()
        uid=db.execute(text('SELECT us_id FROM Tbl_Users WHERE us_email=:email'),{'email':args.correo}).scalar()
        if uid:
            raise SystemExit('La cuenta ya existe. No se modificó.')
        pending=db.execute(text('SELECT password_hash FROM ejecutivo_acceso_solicitud WHERE correo=:email'),{'email':args.correo}).scalar()
        if not pending:
            password=getpass.getpass('Contraseña inicial (15–128 caracteres): ')
            if not 15 <= len(password) <= 128:
                raise SystemExit('Longitud inválida.')
            pending=hasher.hash(password)
        uid=db.execute(text("""INSERT INTO Tbl_Users
          (us_name,us_lastname,us_email,us_account,us_pwd,us_phone,us_rol,is_active,createdBy,updatedBy)
          VALUES (:n,:a,:e,:e,:p,:phone,'Ejecutivo',1,0,0)"""),
          {'n':args.nombres,'a':args.apellidos,'e':args.correo,'p':pending,'phone':args.telefono}).lastrowid
        db.execute(text('UPDATE Tbl_Users SET createdBy=:u,updatedBy=:u WHERE us_id=:u'),{'u':uid})
        db.execute(text("INSERT INTO auth_assignment (item_name,user_id,created_at) VALUES ('Ejecutivo',:u,UNIX_TIMESTAMP())"),{'u':str(uid)})
        db.execute(text('INSERT INTO ejecutivo_acceso (usuario_id,entidad_id) VALUES (:u,:e)'),{'u':uid,'e':entity})
        db.execute(text('DELETE FROM ejecutivo_acceso_solicitud WHERE correo=:email'),{'email':args.correo})
    print('Cuenta ejecutiva autorizada en SSNL.')


def setup_2fa(args):
    import pyotp
    from app.security import cipher
    with engine.begin() as db:
        uid=db.execute(text('SELECT us_id FROM Tbl_Users WHERE us_email=:email AND is_active=1'),{'email':args.correo}).scalar_one()
        current=db.execute(text('SELECT totp_secret FROM ejecutivo_acceso WHERE usuario_id=:uid'),{'uid':uid}).scalar_one()
        if current:
            raise SystemExit('La cuenta ya tiene verificación en dos pasos. No se modificó.')
        totp=pyotp.TOTP(pyotp.random_base32())
        print('Agrega esta clave en tu aplicación de autenticación:',totp.secret)
        code=getpass.getpass('Escribe el código de 6 dígitos para confirmar la vinculación: ')
        if not totp.verify(code,valid_window=1):
            raise SystemExit('Código incorrecto. No se activó la verificación.')
        db.execute(text('UPDATE ejecutivo_acceso SET totp_secret=:s WHERE usuario_id=:uid'),{'s':cipher().encrypt(totp.secret.encode()).decode(),'uid':uid})
    print('Verificación en dos pasos activada.')


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    sub=parser.add_subparsers(dest='command',required=True)
    sub.add_parser('migrate')
    sub.add_parser('seed-wireframe')
    account=sub.add_parser('create-user')
    for key in ['correo','nombres','apellidos']:
        account.add_argument('--'+key,required=True)
    account.add_argument('--telefono',default='')
    account.add_argument('--entidad',default='19',help='Clave INEGI del estado autorizado')
    second_factor=sub.add_parser('setup-2fa')
    second_factor.add_argument('--correo',required=True)
    args=parser.parse_args()
    if args.command=='migrate': migrate()
    elif args.command=='seed-wireframe': seed()
    elif args.command=='setup-2fa': setup_2fa(args)
    else: provision(args)
