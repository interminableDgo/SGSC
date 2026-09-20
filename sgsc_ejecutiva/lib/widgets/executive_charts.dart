import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

import '../core/theme.dart';

class DataBars extends StatelessWidget {
  final List<dynamic> rows;
  final String? active;
  final ValueChanged<String> onSelect;
  const DataBars({
    super.key,
    required this.rows,
    this.active,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty)
      return const Text(
        'Sin datos para mostrar.',
        style: TextStyle(color: muted),
      );
    final max = rows.fold<double>(
      1,
      (n, r) => math.max(n, (r['total'] as num).toDouble()),
    );
    return Column(
      children: rows
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: r['id'] == null ? null : () => onSelect('${r['id']}'),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  color: active != null && active == '${r['id']}'
                      ? blueTint
                      : null,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${r['nombre']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '${r['total']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (r['total'] as num) / max,
                          minHeight: 8,
                          color: salud,
                          backgroundColor: paper,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class TrendChart extends StatefulWidget {
  final List<dynamic> points;
  const TrendChart({super.key, required this.points});
  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? selected;
  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final hasData = points.any(
      (p) => (p['recibidas'] as num) > 0 || (p['resueltas'] as num) > 0,
    );
    if (!hasData)
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 25),
        child: Text(
          'Todavía no hay movimientos en los últimos 12 meses.',
          style: TextStyle(color: muted),
        ),
      );
    return Column(
      children: [
        const Row(
          children: [
            Icon(Icons.horizontal_rule, color: salud),
            Text('Recibidas', style: TextStyle(fontSize: 11)),
            SizedBox(width: 18),
            Icon(Icons.horizontal_rule, color: brand),
            Text('Resueltas', style: TextStyle(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) => GestureDetector(
            onTapDown: (event) => setState(
              () => selected =
                  ((event.localPosition.dx - 28) /
                          (box.maxWidth - 44) *
                          (points.length - 1))
                      .round()
                      .clamp(0, points.length - 1),
            ),
            child: SizedBox(
              height: 185,
              width: double.infinity,
              child: CustomPaint(painter: _TrendPainter(points, selected)),
            ),
          ),
        ),
        if (selected != null && selected! < points.length)
          Text(
            '${points[selected!]['mes']} · ${points[selected!]['recibidas']} recibidas · ${points[selected!]['resueltas']} resueltas',
            style: const TextStyle(fontSize: 11),
          ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<dynamic> points;
  final int? selected;
  _TrendPainter(this.points, this.selected);
  void label(
    Canvas canvas,
    String value,
    Offset position, {
    Color color = muted,
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(fontFamily: 'Mulish', fontSize: 9, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, position);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final max = points.fold<double>(
      1,
      (m, p) => math.max(
        m,
        math.max(
          (p['recibidas'] as num).toDouble(),
          (p['resueltas'] as num).toDouble(),
        ),
      ),
    );
    final plot = Rect.fromLTRB(28, 10, size.width - 16, size.height - 28);
    for (var i = 0; i < 5; i++) {
      final y = plot.bottom - plot.height * i / 4;
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()..color = border,
      );
      label(canvas, (max * i / 4).toStringAsFixed(0), Offset(0, y - 5));
    }
    for (final key in ['recibidas', 'resueltas']) {
      final color = key == 'recibidas' ? salud : brand;
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = plot.left + plot.width * i / math.max(1, points.length - 1);
        final y = plot.bottom - plot.height * (points[i][key] as num) / max;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(
          Offset(x, y),
          selected == i ? 4 : 2,
          Paint()..color = color,
        );
        if (key == 'recibidas' && (i % 3 == 0 || i == points.length - 1)) {
          label(
            canvas,
            '${points[i]['mes']}'.substring(2),
            Offset(x - 13, plot.bottom + 10),
          );
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => true;
}

class RegionMap extends StatefulWidget {
  final List<dynamic> rows;
  final String? active;
  final ValueChanged<String> onSelect;
  const RegionMap({
    super.key,
    required this.rows,
    this.active,
    required this.onSelect,
  });
  @override
  State<RegionMap> createState() => _RegionMapState();
}

class _RegionMapState extends State<RegionMap> {
  late final Future<List<dynamic>> shapes = rootBundle
      .loadString('assets/nl-map.json')
      .then((s) => jsonDecode(s) as List<dynamic>);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      FutureBuilder<List<dynamic>>(
        future: shapes,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox(height: 230);
          return Center(
            child: GestureDetector(
              onTapUp: (event) {
                final point = event.localPosition / (230 / 300);
                for (final item in snapshot.data!) {
                  if (parseSvgPathData(item['path']).contains(point)) {
                    final found = widget.rows.where(
                      (r) => r['nombre'] == item['region'] && r['id'] != null,
                    );
                    if (found.isNotEmpty)
                      widget.onSelect('${found.first['id']}');
                    break;
                  }
                }
              },
              child: SizedBox(
                width: 230,
                height: 383,
                child: CustomPaint(
                  painter: _MapPainter(
                    snapshot.data!,
                    widget.rows,
                    widget.active,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      if (widget.rows.isEmpty)
        const Text(
          'Sin solicitudes para distribuir por región.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ...widget.rows.map(
        (r) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          selected: widget.active != null && widget.active == '${r['id']}',
          leading: const Icon(Icons.square, color: brand, size: 12),
          title: Text('${r['nombre']}', style: const TextStyle(fontSize: 12)),
          trailing: Text(
            '${r['total']}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          onTap: r['id'] == null ? null : () => widget.onSelect('${r['id']}'),
        ),
      ),
      const Text(
        'Mapa de referencia del diseño original. La clasificación visual es aproximada; los conteos corresponden al catálogo de la base de datos.',
        style: TextStyle(fontSize: 10, color: muted),
      ),
    ],
  );
}

class _MapPainter extends CustomPainter {
  final List<dynamic> shapes, rows;
  final String? active;
  _MapPainter(this.shapes, this.rows, this.active);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 300);
    final max = rows.fold<double>(
      1,
      (m, r) => math.max(m, (r['total'] as num).toDouble()),
    );
    for (final shape in shapes) {
      final matching = rows.where((r) => r['nombre'] == shape['region']);
      final row = matching.isEmpty ? null : matching.first;
      final value = row == null ? 0.0 : (row['total'] as num).toDouble();
      final path = parseSvgPathData(shape['path']);
      final selected =
          active != null && row != null && '${row['id']}' == active;
      canvas.drawPath(
        path,
        Paint()
          ..color = value == 0
              ? border
              : brand.withValues(alpha: 0.2 + 0.8 * value / max),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = selected ? ink : Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 1.2 : 0.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
