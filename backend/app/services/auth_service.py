import os
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr, parseaddr
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from fastapi import HTTPException
from app.services.email_template import LOGO_PATH, render_reset_email, reset_plain_text


def mail_configured():
    return bool(os.getenv('SMTP_HOST') and os.getenv('SMTP_FROM') and os.getenv('RESET_URL'))


def build_reset_message(address, token):
    if not mail_configured():
        raise HTTPException(503, 'El servicio de recuperación por correo no está disponible.')
    message = EmailMessage()
    message['Subject'] = 'Recupera tu acceso a SIESAS'
    display, sender = parseaddr(os.environ['SMTP_FROM'])
    message['From'] = formataddr((display or os.getenv('SMTP_FROM_NAME', 'SIESAS · Gobierno de Nuevo León'), sender))
    message['To'] = address
    base = urlsplit(os.environ['RESET_URL'])
    params = [(key, value) for key, value in parse_qsl(base.query) if key != 'reset_token']
    params.append(('reset_token', token))
    link = urlunsplit(base._replace(query=urlencode(params)))
    message.set_content(reset_plain_text(link))
    message.add_alternative(render_reset_email(link), subtype='html')
    message.get_payload()[-1].add_related(LOGO_PATH.read_bytes(), maintype='image', subtype='png', cid='<siesas-logo>', disposition='inline', filename='siesas-nuevo-leon.png')
    return message


def send_reset(address, token):
    message = build_reset_message(address, token)
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
