import logging
import time

import pyotp
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db, SessionLocal
from app.schemas.auth import EmailInput, LoginInput, RegisterInput, ResetInput, VerifyInput
from app.security import (authorized_user, cipher, current_user, digest, hasher,
    issue_token, limit_request, lock_token, now, public_user, verify_password, bearer)
from app.services.auth_service import mail_configured, send_reset

router = APIRouter(prefix='/auth', tags=['Autenticación'])
GENERIC = {'message': 'Si el correo está asociado a una cuenta autorizada, recibirás instrucciones para recuperar el acceso.'}


@router.post('/login')
def login(data: LoginInput, request: Request, db: Session = Depends(get_db)):
    limit_request(db, request, 'login', str(data.correo))
    record = db.execute(text('SELECT us_id AS usuario_id, us_pwd AS password_hash FROM Tbl_Users WHERE us_email=:email FOR UPDATE'), {'email': str(data.correo)}).mappings().first()
    valid = verify_password(record['password_hash'] if record else None, data.password)
    user = authorized_user(db, record['usuario_id']) if record and valid else None
    if not user:
        raise HTTPException(401, 'Correo o contraseña incorrectos, o cuenta sin acceso ejecutivo.')
    kind = 'challenge' if user['totp_secret'] else 'session'
    token = issue_token(db, user['usuario_id'], kind, 5 if kind == 'challenge' else 480)
    if kind == 'session':
        db.execute(text('UPDATE ejecutivo_acceso SET ultimo_acceso=:now WHERE usuario_id=:uid'), {'now': now(), 'uid': user['usuario_id']})
    db.commit()
    return {'token': token, 'requires_2fa': kind == 'challenge', 'user': public_user(user) if kind == 'session' else None}


@router.post('/verify')
def verify(data: VerifyInput, request: Request, db: Session = Depends(get_db)):
    limit_request(db, request, 'verify', digest(data.token))
    token = lock_token(db, data.token, 'challenge')
    user = authorized_user(db, token['usuario_id']) if token else None
    if not user or not user['totp_secret']:
        raise HTTPException(400, 'Verificación vencida. Vuelve a iniciar sesión.')
    totp = pyotp.TOTP(cipher().decrypt(user['totp_secret'].encode()).decode())
    step = int(time.time()) // 30
    matched = next((s for s in (step, step-1, step+1) if pyotp.utils.strings_equal(totp.at(s*30), data.code)), None)
    if matched is None:
        raise HTTPException(400, 'Código incorrecto.')
    result = db.execute(text('''UPDATE ejecutivo_acceso SET totp_last_step=:step
      WHERE usuario_id=:uid AND totp_last_step<:step'''), {'step': matched, 'uid': user['usuario_id']})
    if result.rowcount != 1:
        raise HTTPException(400, 'Este código ya fue utilizado. Espera el siguiente.')
    db.execute(text('UPDATE ejecutivo_token SET usado=:now WHERE token_hash=:token'), {'now': now(), 'token': digest(data.token)})
    session = issue_token(db, user['usuario_id'], 'session', 480)
    db.execute(text('UPDATE ejecutivo_acceso SET ultimo_acceso=:now WHERE usuario_id=:uid'), {'now': now(), 'uid': user['usuario_id']})
    db.commit()
    return {'token': session, 'requires_2fa': False, 'user': public_user(user)}


@router.get('/me')
def me(user=Depends(current_user)):
    return public_user(user)


@router.post('/logout')
def logout(credentials=Depends(bearer), user=Depends(current_user), db: Session = Depends(get_db)):
    db.execute(text('UPDATE ejecutivo_token SET usado=:now WHERE token_hash=:token'), {'now': now(), 'token': digest(credentials.credentials)})
    db.commit()
    return {'message': 'Sesión cerrada.'}


def deliver_reset(address):
    with SessionLocal() as db:
        record = db.execute(text('SELECT us_id FROM Tbl_Users WHERE us_email=:email'), {'email': address}).scalar()
        user = authorized_user(db, record) if record else None
        if not user:
            return
        # Serialize concurrent requests for the same account.
        db.execute(text('SELECT us_id FROM Tbl_Users WHERE us_id=:uid FOR UPDATE'), {'uid': record})
        db.execute(text("UPDATE ejecutivo_token SET usado=:now WHERE usuario_id=:uid AND tipo='reset' AND usado IS NULL"), {'now': now(), 'uid': record})
        token = issue_token(db, record, 'reset', 30)
        try:
            send_reset(address, token)
            db.commit()
        except Exception:
            db.rollback()
            logging.getLogger(__name__).error('No se pudo entregar un correo de recuperación; revisar SMTP.')


@router.post('/forgot-password', status_code=202)
def forgot(data: EmailInput, request: Request, tasks: BackgroundTasks, db: Session = Depends(get_db)):
    limit_request(db, request, 'forgot', str(data.correo))
    if not mail_configured():
        raise HTTPException(503, 'El servicio de recuperación por correo no está disponible.')
    tasks.add_task(deliver_reset, str(data.correo))
    return GENERIC


@router.post('/reset-password')
def reset(data: ResetInput, db: Session = Depends(get_db)):
    token = lock_token(db, data.token, 'reset')
    if not token or not authorized_user(db, token['usuario_id']):
        raise HTTPException(400, 'El enlace no es válido o ya venció. Solicita uno nuevo.')
    db.execute(text('UPDATE Tbl_Users SET us_pwd=:hash, updated=CURRENT_TIMESTAMP, updatedBy=:uid WHERE us_id=:uid'), {'hash': hasher.hash(data.password), 'uid': token['usuario_id']})
    db.execute(text('UPDATE ejecutivo_token SET usado=:now WHERE usuario_id=:uid AND usado IS NULL'), {'now': now(), 'uid': token['usuario_id']})
    db.commit()
    return {'message': 'Contraseña actualizada. Ya puedes iniciar sesión.'}


@router.post('/request-access', status_code=202)
def register(data: RegisterInput, request: Request, db: Session = Depends(get_db)):
    limit_request(db, request, 'register', str(data.correo))
    password_hash = hasher.hash(data.password)
    existing = db.execute(text('SELECT us_id FROM Tbl_Users WHERE us_email=:email'), {'email': str(data.correo)}).scalar()
    if not existing:
        db.execute(text('''INSERT IGNORE INTO ejecutivo_acceso_solicitud (correo, password_hash)
          VALUES (:email, :hash)'''), {'email': str(data.correo), 'hash': password_hash})
        db.commit()
    return {'message': 'Solicitud recibida. La administración debe autorizar tu cuenta y asignar tu estado.'}
