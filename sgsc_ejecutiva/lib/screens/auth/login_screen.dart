import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/executive_api.dart';
import '../../widgets/executive_widgets.dart';

class LoginScreen extends StatefulWidget {
  final ExecutiveApi api;
  final ValueChanged<Map<String, dynamic>> onLogin;
  const LoginScreen({super.key, required this.api, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  final code = TextEditingController();
  late String mode;
  String? resetToken;
  String? challenge;
  String? error;
  String message = '';
  bool busy = false, show = false;
  @override
  void initState() {
    super.initState();
    resetToken = Uri.base.queryParameters['reset_token'];
    mode = resetToken == null ? 'login' : 'reset';
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmation.dispose();
    code.dispose();
    super.dispose();
  }

  void go(String next) => setState(() {
    mode = next;
    error = null;
    password.clear();
    confirmation.clear();
    code.clear();
    show = false;
  });
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = widget.api;
      if (mode == 'login' || mode == 'verify') {
        final result = mode == 'login'
            ? await api.post('/auth/login', {
                'correo': email.text.trim(),
                'password': password.text,
              })
            : await api.post('/auth/verify', {
                'token': challenge,
                'code': code.text,
              });
        if (!mounted) return;
        if (result['requires_2fa'] == true) {
          challenge = result['token'] as String;
          go('verify');
        } else {
          api.token = result['token'] as String;
          widget.onLogin(Map<String, dynamic>.from(result['user']));
        }
      } else {
        final path = {
          'recover': '/auth/forgot-password',
          'reset': '/auth/reset-password',
          'register': '/auth/request-access',
        }[mode]!;
        final data = mode == 'recover'
            ? {'correo': email.text.trim()}
            : mode == 'reset'
            ? {'token': resetToken, 'password': password.text}
            : {'correo': email.text.trim(), 'password': password.text};
        final result = await api.post(path, data);
        if (!mounted) return;
        message = result['message'] as String;
        go(mode == 'recover' ? 'mail' : 'done');
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final newPassword = mode == 'register' || mode == 'reset';
    final title = {
      'login': 'Iniciar sesión',
      'recover': 'Recuperar contraseña',
      'register': 'Solicitar acceso',
      'reset': 'Restablecer contraseña',
      'verify': 'Verificación en dos pasos',
      'mail': 'Revisa tu correo',
      'done': 'Listo',
    }[mode]!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset('assets/nl-logo.png', height: 72),
            const SizedBox(height: 18),
            const Text(
              'SIESAS · EJECUTIVO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: brand,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 28),
            if (mode == 'mail' || mode == 'done') ...[
              Icon(
                mode == 'mail'
                    ? Icons.mark_email_read_outlined
                    : Icons.check_circle_outline,
                size: 54,
                color: salud,
              ),
              const SizedBox(height: 20),
              Notice(message),
              FilledButton(
                onPressed: () => go('login'),
                child: const Text('Volver al inicio de sesión'),
              ),
            ] else
              Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (mode == 'recover')
                      const Notice(
                        'Escribe el correo asociado a tu cuenta. Te enviaremos un enlace para elegir una nueva contraseña.',
                      ),
                    if (mode == 'login')
                      const Notice(
                        'Consulta las solicitudes y los indicadores de tu estado con tu cuenta autorizada.',
                      ),
                    if (mode != 'verify' && mode != 'reset')
                      LabeledField(
                        'Correo electrónico',
                        TextFormField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            hintText: 'correo@ejemplo.com',
                          ),
                          maxLength: 180,
                          validator: (v) =>
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(v?.trim() ?? '')
                              ? null
                              : 'Ingresa un correo válido.',
                        ),
                      ),
                    if (mode == 'login' || newPassword) ...[
                      LabeledField(
                        mode == 'reset' ? 'Nueva contraseña' : 'Contraseña',
                        TextFormField(
                          controller: password,
                          obscureText: !show,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: [
                            newPassword
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          validator: (v) {
                            final n = (v ?? '').runes.length;
                            return n < (newPassword ? 15 : 1) || n > 128
                                ? (newPassword
                                      ? 'Usa de 15 a 128 caracteres.'
                                      : 'Ingresa tu contraseña.')
                                : null;
                          },
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        title: const Text('Mostrar contraseña'),
                        value: show,
                        onChanged: (v) => setState(() => show = v!),
                      ),
                    ],
                    if (newPassword) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text(
                          'De 15 a 128 caracteres. Puedes usar espacios y una frase larga.',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                      LabeledField(
                        'Confirmar contraseña',
                        TextFormField(
                          controller: confirmation,
                          obscureText: !show,
                          validator: (v) => v == password.text
                              ? null
                              : 'Las contraseñas no coinciden.',
                        ),
                      ),
                    ],
                    if (mode == 'verify') ...[
                      const Notice(
                        'Introduce el código de tu aplicación de autenticación. La verificación vence en 5 minutos.',
                      ),
                      LabeledField(
                        'Código de verificación',
                        TextFormField(
                          controller: code,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                              ? null
                              : 'Ingresa los 6 dígitos.',
                        ),
                      ),
                    ],
                    if (mode == 'register')
                      const Notice(
                        'La administración debe autorizar tu cuenta y asignar tu estado antes de habilitar el acceso.',
                      ),
                    if (error != null) Notice(error!, error: true),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              {
                                'login': 'Iniciar sesión',
                                'recover': 'Enviar enlace',
                                'reset': 'Guardar contraseña',
                                'register': 'Solicitar acceso',
                                'verify': 'Verificar',
                              }[mode]!,
                            ),
                    ),
                    const SizedBox(height: 16),
                    if (mode == 'login') ...[
                      TextButton(
                        onPressed: busy ? null : () => go('recover'),
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => go('register'),
                        child: const Text('Solicitar cuenta ejecutiva'),
                      ),
                    ] else
                      TextButton(
                        onPressed: busy ? null : () => go('login'),
                        child: const Text('Volver al inicio de sesión'),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            const Text(
              'Secretaría de Salud · Nuevo León',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
