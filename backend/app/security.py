import bcrypt
import hashlib
import os
import secrets
import time
from datetime import datetime, timedelta, timezone

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from cryptography.fernet import Fernet
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db

hasher = PasswordHasher()
dummy_hash = hasher.hash(secrets.token_urlsafe(32))
bearer = HTTPBearer(auto_error=False)


def digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def verify_password(encoded, password):
    try:
        if encoded and encoded.startswith(('$2a$', '$2b$', '$2y$')):
            # PHP bcrypt uses at most 72 bytes; new passwords continue using Argon2.
            return bcrypt.checkpw(password.encode('utf-8')[:72], encoded.encode('ascii'))
        return hasher.verify(encoded or dummy_hash, password)
    except (InvalidHashError, VerificationError, ValueError):
        return False


def cipher():
    key = os.getenv('AUTH_ENCRYPTION_KEY')
    if not key:
        raise HTTPException(503, 'La verificación en dos pasos no está configurada.')
    return Fernet(key.encode())


def rate_limit(db, key, maximum=10, seconds=900):
    window = int(time.time()) // seconds
    key = digest(key)
    db.execute(text('''INSERT INTO ejecutivo_limite (clave, ventana, intentos)
      VALUES (:key, :window, 1) ON DUPLICATE KEY UPDATE
      intentos=IF(ventana=:window, intentos+1, 1), ventana=:window'''),
      {'key': key, 'window': window})
    count = db.execute(text('SELECT intentos FROM ejecutivo_limite WHERE clave=:key'), {'key': key}).scalar_one()
    db.commit()
    if count > maximum:
        raise HTTPException(429, 'Demasiados intentos. Intenta más tarde.', headers={'Retry-After': str(seconds)})


def limit_request(db, request: Request, action, identity=''):
    ip = request.client.host if request.client else 'unknown'
    rate_limit(db, f'{action}:ip:{ip}', maximum=30)
    if identity:
        rate_limit(db, f'{action}:identity:{identity.lower()}', maximum=6)


def issue_token(db, user_id, kind, minutes):
    raw = secrets.token_urlsafe(32)
    db.execute(text('''INSERT INTO ejecutivo_token (token_hash, usuario_id, tipo, expira)
      VALUES (:token, :uid, :kind, :expires)'''),
      {'token': digest(raw), 'uid': user_id, 'kind': kind, 'expires': now()+timedelta(minutes=minutes)})
    return raw


def lock_token(db, raw, kind):
    """Use the same user -> token lock order as password changes and issuance."""
    key = digest(raw)
    uid = db.execute(text('SELECT usuario_id FROM ejecutivo_token WHERE token_hash=:key'), {'key': key}).scalar()
    if uid is None:
        return None
    db.execute(text('SELECT us_id FROM Tbl_Users WHERE us_id=:uid FOR UPDATE'), {'uid': uid})
    return db.execute(text('''SELECT * FROM ejecutivo_token WHERE token_hash=:key
      AND tipo=:kind AND usado IS NULL AND expira>:now FOR UPDATE'''),
      {'key': key, 'kind': kind, 'now': now()}).mappings().first()


USER_SQL = """SELECT u.us_id AS usuario_id, u.us_name AS nombres, u.us_lastname AS apellidos, u.us_email AS correo,
 a.entidad_id, e.nom_ent AS entidad, e.cve_ent AS clave_inegi, a.totp_secret, a.totp_last_step
 FROM Tbl_Users u JOIN ejecutivo_acceso a ON a.usuario_id=u.us_id
 JOIN INEGI_Cat_Entidades e ON e.id=a.entidad_id
 WHERE u.is_active=1 AND EXISTS (
 SELECT 1 FROM auth_assignment aa JOIN auth_item ai ON ai.name=aa.item_name
 WHERE aa.user_id=CAST(u.us_id AS CHAR) AND ai.name='Ejecutivo' AND ai.type=1)"""


def authorized_user(db, uid):
    return db.execute(text(USER_SQL + ' AND u.us_id=:uid'), {'uid': uid}).mappings().first()


def public_user(user):
    return {k: v for k, v in dict(user).items() if k not in ('totp_secret', 'totp_last_step')}


def current_user(credentials: HTTPAuthorizationCredentials = Depends(bearer), db: Session = Depends(get_db)):
    if not credentials:
        raise HTTPException(401, 'Inicia sesión para continuar.')
    token = db.execute(text('''SELECT usuario_id FROM ejecutivo_token
      WHERE token_hash=:token AND tipo='session' AND usado IS NULL AND expira>:now'''),
      {'token': digest(credentials.credentials), 'now': now()}).scalar()
    user = authorized_user(db, token) if token else None
    if not user:
        raise HTTPException(401, 'Tu sesión venció. Inicia sesión nuevamente.')
    return dict(user)
