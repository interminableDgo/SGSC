from app.services.auth_service import build_reset_message
from app.services.email_template import render_reset_email
from email import policy
from email.parser import BytesParser


def test_email_embeds_logo_and_has_accessible_text(monkeypatch):
    monkeypatch.setenv('SMTP_HOST','smtp.example.com')
    monkeypatch.setenv('SMTP_FROM','no-reply@example.com')
    monkeypatch.setenv('RESET_URL','https://example.com/?lang=es&reset_token=old')
    message=build_reset_message('recipient@example.com','new-test-token')
    message=BytesParser(policy=policy.default).parsebytes(message.as_bytes(policy=policy.SMTP))
    plain=message.get_body(preferencelist=('plain',)).get_content()
    html=message.get_body(preferencelist=('html',)).get_content()
    assert 'reset_token=new-test-token' in plain
    assert 'reset_token=old' not in plain
    assert 'lang=es&amp;reset_token=new-test-token' in html
    logo=next(p for p in message.walk() if p.get_content_type()=='image/png')
    cid=str(logo['Content-ID'])
    assert cid.startswith('<') and cid.endswith('@example.com>')
    assert f'src="cid:{cid[1:-1]}"' in html
    related=next(p for p in message.walk() if p.get_content_type()=='multipart/related')
    assert related is message
    assert related.get_param('type')=='multipart/alternative'
    assert related.get_payload()[0].get_content_type()=='multipart/alternative'
    assert related.get_param('start')==related.get_payload()[0]['Content-ID']
    assert logo['X-Attachment-Id']==cid[1:-1]
    assert message['Date'] and message['Message-ID']
    assert logo.get_content_disposition()=='inline'
    assert logo.get_payload(decode=True).startswith(b'\x89PNG')
    assert '30 minutos' in html


def test_html_escapes_dynamic_url():
    html=render_reset_email('https://example.com/?q="<script>alert(1)</script>')
    assert '<script>' not in html
    assert '&lt;script&gt;' in html
