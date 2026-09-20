from app.services.auth_service import build_reset_message
from app.services.email_template import render_reset_email


def test_email_embeds_logo_and_has_accessible_text(monkeypatch):
    monkeypatch.setenv('SMTP_HOST','smtp.example.com')
    monkeypatch.setenv('SMTP_FROM','no-reply@example.com')
    monkeypatch.setenv('RESET_URL','https://example.com/?lang=es&reset_token=old')
    message=build_reset_message('recipient@example.com','new-test-token')
    plain=message.get_body(preferencelist=('plain',)).get_content()
    html=message.get_body(preferencelist=('html',)).get_content()
    assert 'reset_token=new-test-token' in plain
    assert 'reset_token=old' not in plain
    assert 'lang=es&amp;reset_token=new-test-token' in html
    assert 'cid:siesas-logo' in html
    logo=next(p for p in message.walk() if p.get_content_type()=='image/png')
    assert logo['Content-ID']=='<siesas-logo>'
    assert logo.get_content_disposition()=='inline'
    assert logo.get_payload(decode=True).startswith(b'\x89PNG')
    assert '30 minutos' in html


def test_html_escapes_dynamic_url():
    html=render_reset_email('https://example.com/?q="<script>alert(1)</script>')
    assert '<script>' not in html
    assert '&lt;script&gt;' in html
