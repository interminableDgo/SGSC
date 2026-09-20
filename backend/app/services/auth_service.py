import os
import smtplib
import ssl
from email.message import EmailMessage
from urllib.parse import quote

from fastapi import HTTPException


def mail_configured():
    return bool(os.getenv('SMTP_HOST') and os.getenv('SMTP_FROM') and os.getenv('RESET_URL'))


def send_reset(address, token):
    if not mail_configured():
        raise HTTPException(503, 'El servicio de recuperación por correo no está disponible.')
    message = EmailMessage()
    message['Subject'] = 'Restablecimiento de contraseña — SIESAS'
    message['From'] = os.environ['SMTP_FROM']
    message['To'] = address
    base = os.environ['RESET_URL']
    link = base + ('&' if '?' in base else '?') + 'reset_token=' + quote(token)
    message.set_content(f'''Estimada persona usuaria:

Recibimos una solicitud para restablecer la contraseña de su cuenta.
Utilice este enlace dentro de los próximos 30 minutos:
{link}

Si no realizó esta solicitud, ignore este mensaje.

Equipo SIESAS''')
    secure = os.getenv('SMTP_SSL', 'false').lower() == 'true'
    client = smtplib.SMTP_SSL if secure else smtplib.SMTP
    kwargs = {'timeout': 15}
    if secure:
        kwargs['context'] = ssl.create_default_context()
    with client(os.environ['SMTP_HOST'], int(os.getenv('SMTP_PORT', '465' if secure else '587')), **kwargs) as smtp:
        if not secure:
            smtp.starttls(context=ssl.create_default_context())
        if os.getenv('SMTP_USER'):
            smtp.login(os.environ['SMTP_USER'], os.environ.get('SMTP_PASSWORD', ''))
        smtp.send_message(message)
