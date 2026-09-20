import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../services/executive_api.dart';
import '../../widgets/executive_widgets.dart';
import '../../core/theme.dart';

class NewRequestScreen extends StatefulWidget {
  final ExecutiveApi api;
  final Map<String, dynamic> catalogs;
  final String entity;
  final VoidCallback onBack;
  final ValueChanged<String> onSaved;
  const NewRequestScreen({
    super.key,
    required this.api,
    required this.catalogs,
    required this.entity,
    required this.onBack,
    required this.onSaved,
  });
  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final form = GlobalKey<FormState>();
  final names = TextEditingController(),
      surnames = TextEditingController(),
      description = TextEditingController();
  final Map<String, int?> values = {};
  final idempotency = const Uuid().v4();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    names.dispose();
    surnames.dispose();
    description.dispose();
    super.dispose();
  }

  bool get missing => [
    'municipios',
    'apoyos',
    'dependencias',
  ].any((key) => (widget.catalogs[key] as List? ?? []).isEmpty);
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.api.post('/ejecutivo/solicitudes', {
        'nombres': names.text.trim(),
        'apellidos': surnames.text.trim(),
        'descripcion': description.text.trim(),
        ...values,
        'idempotencia': idempotency,
      });
      if (mounted) widget.onSaved('${result['folio']}');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget select(
    String label,
    String key,
    String catalog, {
    bool required = true,
  }) {
    final options = widget.catalogs[catalog] as List? ?? [];
    return LabeledField(
      label,
      DropdownButtonFormField<int>(
        initialValue: values[key],
        isExpanded: true,
        hint: Text(
          options.isEmpty
              ? 'Sin opciones disponibles'
              : required
              ? 'Selecciona…'
              : 'Sin información',
        ),
        items: [
          if (!required)
            const DropdownMenuItem<int>(
              value: null,
              child: Text('Sin información'),
            ),
          ...options.map(
            (r) => DropdownMenuItem<int>(
              value: r['id'] as int,
              child: Text('${r['nombre']}', overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: busy || options.isEmpty
            ? null
            : (v) => setState(() => values[key] = v),
        validator: (v) =>
            required && v == null ? 'Selecciona una opción.' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading('Nueva solicitud', onBack: busy ? () {} : widget.onBack),
        Notice(
          'Registro ejecutivo para ${widget.entity}. La solicitud se guardará con estatus Recibida y prioridad Media.',
        ),
        if (missing)
          const Notice(
            'Faltan municipios, tipos de apoyo o dependencias. La administración debe completar los catálogos antes de registrar solicitudes.',
            error: true,
          ),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                'Nombre(s) del beneficiario',
                TextFormField(
                  controller: names,
                  maxLength: 150,
                  enabled: !busy,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Ingresa el nombre.' : null,
                ),
              ),
              LabeledField(
                'Apellido(s) del beneficiario',
                TextFormField(
                  controller: surnames,
                  maxLength: 150,
                  enabled: !busy,
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Ingresa los apellidos.'
                      : null,
                ),
              ),
              select('Municipio', 'municipio_id', 'municipios'),
              select('Tipo de apoyo', 'tipo_apoyo_id', 'apoyos'),
              select('Dependencia', 'dependencia_id', 'dependencias'),
              select(
                'Grupo vulnerable',
                'grupo_vulnerable_id',
                'grupos',
                required: false,
              ),
              LabeledField(
                'Descripción de la solicitud',
                TextFormField(
                  controller: description,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 5000,
                  enabled: !busy,
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Describe la solicitud.'
                      : null,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: Text(
                  'Se conservará el usuario que realiza el registro. Los campos opcionales sin información quedarán vacíos.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
              if (error != null) Notice(error!, error: true),
              FilledButton(
                onPressed: busy || missing ? null : save,
                child: Text(busy ? 'Guardando…' : 'Registrar solicitud'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
