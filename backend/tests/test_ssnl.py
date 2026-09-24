import bcrypt
from app.security import verify_password
from app.services.ssnl_registration import Beneficiary
from pydantic import ValidationError
import pytest


def test_yii_bcrypt_and_current_argon2_compatibility():
    secret='Una contraseña compatible con SSNL'
    encoded=bcrypt.hashpw(secret.encode(),bcrypt.gensalt()).decode().replace('$2b$','$2y$',1)
    assert verify_password(encoded,secret)
    assert not verify_password(encoded,'incorrecta')
    assert not verify_password('hash-invalido',secret)


def test_future_birth_is_rejected():
    with pytest.raises(ValidationError):
        Beneficiary(nombres='A',apellidos='B',fecha_nacimiento='2999-01-01',genero_id=1,
          municipio_nacimiento_id=1,municipio_id=1,calle='X',numero='1',colonia_id=1,
          codigo_postal='64000',tiempo_residencia=0,con_quien_vive='Familia',numero_hijos=0,
          seguridad_social_id=1,grupo_vulnerable_id=1)
