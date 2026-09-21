import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../core/theme.dart';
import '../services/executive_api.dart';
import 'executive_widgets.dart';

class PeriodComparison extends StatefulWidget {
  final ExecutiveApi api;
  final Map<String, String> filters;
  const PeriodComparison({super.key, required this.api, required this.filters});
  @override
  State<PeriodComparison> createState() => _PeriodComparisonState();
}

class _PeriodComparisonState extends State<PeriodComparison> {
  static const months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  bool annual = false;
  late DateTime a, b;
  Map<String, dynamic>? result;
  String? error;
  bool busy = true;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    b = DateTime(now.year, now.month - 1);
    a = DateTime(b.year - 1, b.month);
    compare();
  }

  @override
  void didUpdateWidget(covariant PeriodComparison oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.filters, widget.filters)) compare();
  }

  String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String label(DateTime d) =>
      annual ? '${d.year}' : '${months[d.month - 1]} ${d.year}';
  Future<void> compare() async {
    final current = ++generation;
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    final query = Map<String, String>.from(widget.filters)
      ..remove('fecha_inicio')
      ..remove('fecha_fin');
    for (final entry in {'a': a, 'b': b}.entries) {
      final d = entry.value;
      query['${entry.key}_inicio'] = iso(
        DateTime(d.year, annual ? 1 : d.month),
      );
      query['${entry.key}_fin'] = iso(
        annual ? DateTime(d.year, 12, 31) : DateTime(d.year, d.month + 1, 0),
      );
    }
    try {
      final response = await widget.api.get('/ejecutivo/comparacion', query);
      if (mounted && current == generation) setState(() => result = response);
    } catch (e) {
      if (mounted && current == generation) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && current == generation) setState(() => busy = false);
    }
  }

  void mode(bool value) {
    if (annual == value) return;
    setState(() {
      annual = value;
      final now = DateTime.now();
      b = value ? DateTime(now.year - 1) : DateTime(now.year, now.month - 1);
      a = DateTime(b.year - 1, b.month);
    });
    compare();
  }

  Future<void> pick(bool reference) async {
    var selected = reference ? a : b;
    final chosen = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    reference ? 'Periodo de referencia' : 'Periodo a analizar',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    annual ? 'Selecciona un año' : 'Selecciona un mes y un año',
                  ),
                  if (annual)
                    SizedBox(
                      height: 280,
                      child: YearPicker(
                        firstDate: DateTime(2000),
                        lastDate: DateTime(DateTime.now().year),
                        selectedDate: selected,
                        onChanged: (d) =>
                            update(() => selected = DateTime(d.year)),
                      ),
                    ),
                  if (!annual) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Año anterior',
                          onPressed: selected.year > 2000
                              ? () => update(
                                  () => selected = DateTime(
                                    selected.year - 1,
                                    selected.month,
                                  ),
                                )
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          '${selected.year}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          tooltip: 'Año siguiente',
                          onPressed: selected.year < DateTime.now().year
                              ? () => update(
                                  () => selected = DateTime(
                                    selected.year + 1,
                                    selected.month,
                                  ),
                                )
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          12,
                          (i) => SizedBox(
                            width: (constraints.maxWidth - 16) / 3,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                backgroundColor: selected.month == i + 1
                                    ? blueTint
                                    : null,
                                foregroundColor: ink,
                                side: BorderSide(
                                  color: selected.month == i + 1
                                      ? salud
                                      : border,
                                ),
                              ),
                              onPressed: () => update(
                                () => selected = DateTime(selected.year, i + 1),
                              ),
                              child: Text(
                                months[i],
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.pop(sheet, selected),
                    child: Text('Usar ${label(selected)}'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(sheet),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (reference) {
        a = chosen;
      } else {
        b = chosen;
      }
    });
    compare();
  }

  Widget period(bool reference) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(14),
        foregroundColor: ink,
        alignment: Alignment.centerLeft,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () => pick(reference),
      child: Row(
        children: [
          Icon(
            reference ? Icons.history : Icons.calendar_month_outlined,
            color: reference ? muted : salud,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reference ? 'Comparado con' : 'Periodo a analizar',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                Text(
                  label(reference ? a : b),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.expand_more, size: 22),
        ],
      ),
    ),
  );
  Widget metric(String key, String title) {
    final av = result!['a'][key] as num, bv = result!['b'][key] as num;
    final delta = result!['variacion'][key];
    final diff = delta['diferencia'] as num;
    final pct = delta['porcentaje'] as num?;
    final maxValue = (av > bv ? av : bv).toDouble();
    String change = diff == 0
        ? 'Sin cambio'
        : '${diff.abs()} ${diff > 0 ? 'más' : 'menos'}';
    if (pct != null && diff != 0) change += ' (${pct.abs()} %)';
    if (pct == null) change += ' · referencia en cero';
    Widget bar(DateTime date, num value, Color color) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label(date), style: const TextStyle(fontSize: 12)),
              ),
              Text(
                '$value',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: maxValue == 0 ? 0 : value / maxValue,
              minHeight: 6,
              color: color,
              backgroundColor: paper,
            ),
          ),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: key == 'total' ? blueTint : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          Text(
            '$bv',
            style: TextStyle(
              fontSize: key == 'total' ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          Text(change, style: const TextStyle(fontSize: 13, color: ink)),
          bar(b, bv, salud),
          bar(a, av, muted),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ExecutiveCard(
    title: 'Comparar periodos',
    source: 'Solicitudes recibidas en cada periodo y su estatus actual. El cambio se calcula respecto al periodo de referencia. Se conservan los filtros de municipio y catálogo; las fechas elegidas aquí sustituyen el rango general. Un aumento de volumen no implica una mejora.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          ),
          segments: const [
            ButtonSegment(value: false, label: Text('Meses')),
            ButtonSegment(value: true, label: Text('Años')),
          ],
          selected: {annual},
          onSelectionChanged: (values) => mode(values.first),
        ),
        period(false),
        period(true),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton(
              onPressed: () {
                setState(
                  () => a = annual
                      ? DateTime(b.year - 1)
                      : DateTime(b.year, b.month - 1),
                );
                compare();
              },
              child: const Text('Periodo anterior'),
            ),
            if (!annual)
              TextButton(
                onPressed: () {
                  setState(() => a = DateTime(b.year - 1, b.month));
                  compare();
                },
                child: const Text('Año anterior'),
              ),
          ],
        ),
        Text(
          widget.filters.keys.any((k) => !k.startsWith('fecha_'))
              ? 'Con los filtros del panel · actualización automática'
              : 'Todos los registros de tu estado · actualización automática',
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        if (b.year == DateTime.now().year &&
                (annual || b.month >= DateTime.now().month) ||
            a.year == DateTime.now().year &&
                (annual || a.month >= DateTime.now().month))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Periodo en curso o futuro: las cifras pueden estar incompletas.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (busy)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Actualizando comparación',
              ),
            ),
          ),
        if (error != null) ...[
          Notice(error!, error: true),
          OutlinedButton(onPressed: compare, child: const Text('Reintentar')),
        ],
        if (result != null) ...[
          if ((result!['a']['datos_demo'] as num? ?? 0) +
                  (result!['b']['datos_demo'] as num? ?? 0) >
              0)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Incluye datos de prueba DEMO',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
          if (result!['a']['total'] == 0 && result!['b']['total'] == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Sin solicitudes en ambos periodos. Prueba otras fechas o ajusta los filtros.',
              ),
            ),
          metric('total', 'Solicitudes recibidas'),
          metric('activas', 'Activas actualmente'),
          metric('resueltas', 'Resueltas actualmente'),
        ],
      ],
    ),
  );
}
