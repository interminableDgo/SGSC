import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';

import '../../core/theme.dart';
import '../../services/executive_api.dart';
import '../../widgets/executive_widgets.dart';
import '../../widgets/executive_charts.dart';
import '../solicitudes/nueva_solicitud_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ExecutiveApi api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const DashboardScreen({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
  });
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? summary, catalogs, detail;
  List<dynamic> rows = [];
  final Map<String, String> filters = {};
  String screen = 'dashboard';
  String? error, message;
  bool loading = true, showFilters = false, exporting = false;
  int page = 0, total = 0, generation = 0;
  static const filterDefinitions = [
    ['Municipio', 'municipio_id', 'municipios'],
    ['Región', 'region_id', 'regiones'],
    ['Tipo de apoyo', 'tipo_apoyo_id', 'apoyos'],
    ['Dependencia', 'dependencia_id', 'dependencias'],
    ['Grupo vulnerable', 'grupo_vulnerable_id', 'grupos'],
    ['Estatus', 'estatus_id', 'estatus'],
  ];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final current = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final query = Map<String, String>.from(filters);
      final results = await Future.wait([
        widget.api.get('/ejecutivo/dashboard', query),
        widget.api.get('/ejecutivo/solicitudes', {...query, 'page': '$page'}),
        if (catalogs == null) widget.api.get('/ejecutivo/catalogos'),
      ]);
      if (!mounted || current != generation) return;
      setState(() {
        summary = results[0];
        rows = results[1]['items'] as List;
        total = results[1]['total'] as int;
        if (results.length > 2) catalogs = results[2];
      });
    } catch (e) {
      if (!mounted || current != generation) return;
      if (e is ApiException && e.status == 401) {
        widget.onLogout();
        return;
      }
      setState(() => error = e.toString());
    } finally {
      if (mounted && current == generation) setState(() => loading = false);
    }
  }

  void filter(String key, String? value, {bool toggle = false}) {
    setState(() {
      if (value == null || value.isEmpty || (toggle && filters[key] == value)) {
        filters.remove(key);
      } else {
        filters[key] = value;
      }
      page = 0;
    });
    load();
  }

  void clear() {
    setState(() {
      filters.clear();
      page = 0;
    });
    load();
  }

  String filterLabel(String key, String value) {
    for (final def in filterDefinitions) {
      if (def[1] == key) {
        for (final r in (catalogs?[def[2]] as List? ?? [])) {
          if ('${r['id']}' == value) return '${r['nombre']}';
        }
      }
    }
    return '${key == 'fecha_inicio'
        ? 'Desde'
        : key == 'fecha_fin'
        ? 'Hasta'
        : key}: $value';
  }

  Future<void> export(String format) async {
    setState(() {
      exporting = true;
      message = null;
    });
    try {
      final bytes = await widget.api.export(format, Map.from(filters));
      final file = XFile.fromData(
        bytes,
        name: 'SIESAS-ejecutivo.$format',
        mimeType: format == 'pdf' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (kIsWeb) {
        await file.saveTo('SIESAS-ejecutivo.$format');
      } else if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [file],
            fileNameOverrides: ['SIESAS-ejecutivo.$format'],
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      } else {
        final location = await getSaveLocation(
          suggestedName: 'SIESAS-ejecutivo.$format',
        );
        if (location == null) return;
        await file.saveTo(location.path);
      }
      if (mounted) setState(() => message = 'Reporte generado.');
    } catch (e) {
      if (mounted) {
        setState(
          () => message =
              'No se pudo exportar el reporte. ${e is ApiException ? e.message : 'Intenta nuevamente.'}',
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> openDetail(int id) async {
    setState(() {
      screen = 'detail';
      detail = null;
      error = null;
    });
    try {
      final value = await widget.api.get('/ejecutivo/solicitudes/$id');
      if (mounted) setState(() => detail = value);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await widget.api.post('/auth/logout', {});
    } catch (_) {}
    if (mounted) widget.onLogout();
  }

  void back() {
    setState(() {
      screen = 'dashboard';
      error = null;
    });
    load();
  }

  List<dynamic> group(String key) => summary?[key] as List? ?? [];
  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: const TextStyle(
        color: brand,
        fontSize: 11,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
  Widget bars(String title, String dataKey, String filterKey, String source) =>
      ExecutiveCard(
        title: title,
        source: source,
        child: DataBars(
          rows: group(dataKey),
          active: filters[filterKey],
          onSelect: (v) => filter(filterKey, v, toggle: true),
        ),
      );

  Widget filterPanel() => ExecutiveCard(
    title: 'Filtrar solicitudes',
    child: Column(
      children: [
        ...filterDefinitions.map((def) {
          final options = catalogs?[def[2]] as List? ?? [];
          return LabeledField(
            def[0],
            DropdownButtonFormField<String>(
              key: ValueKey('${def[1]}-${filters[def[1]]}'),
              initialValue: filters[def[1]] ?? '',
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(
                    options.isEmpty ? 'Sin opciones disponibles' : 'Todos',
                  ),
                ),
                ...options.map(
                  (r) => DropdownMenuItem(
                    value: '${r['id']}',
                    child: Text(
                      '${r['nombre']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: loading || options.isEmpty
                  ? null
                  : (v) => filter(def[1], v),
            ),
          );
        }),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: loading
                    ? null
                    : () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          helpText: 'Fechas de recepción',
                          saveText: 'Aplicar',
                        );
                        if (range != null) {
                          filters['fecha_inicio'] = range.start
                              .toIso8601String()
                              .substring(0, 10);
                          filters['fecha_fin'] = range.end
                              .toIso8601String()
                              .substring(0, 10);
                          page = 0;
                          load();
                        }
                      },
                child: const Text('Periodo'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: loading ? null : clear,
                child: const Text('Limpiar'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget profile() => SingleChildScrollView(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading('Mi perfil', onBack: back),
        ExecutiveCard(
          title: '${widget.user['nombres']} ${widget.user['apellidos']}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: blueTint,
                radius: 30,
                child: Icon(Icons.person_outline, color: salud, size: 32),
              ),
              const SizedBox(height: 16),
              Text('${widget.user['correo']}'),
              const Text('Rol · Ejecutivo'),
              const SizedBox(height: 14),
              Text(
                'Estado asignado: ${widget.user['entidad']}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Consulta estatal de todas las dependencias. El estado lo asigna la administración.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: logout,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );

  Widget detailView() => SingleChildScrollView(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading('Detalle de solicitud', onBack: back),
        if (error != null)
          Notice(error!, error: true)
        else if (detail == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          ExecutiveCard(
            title: '${detail!['folio']}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(
                  label: Text('${detail!['estatus']}'),
                  backgroundColor: blueTint,
                  side: BorderSide.none,
                ),
                const SizedBox(height: 10),
                Text(
                  '${detail!['nombres']} ${detail!['apellidos']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ...{
                  'Municipio': 'municipio',
                  'Tipo de apoyo': 'tipo_apoyo',
                  'Dependencia': 'dependencia',
                  'Región': 'region',
                  'Grupo vulnerable': 'grupo_vulnerable',
                  'Prioridad': 'prioridad',
                  'Recibida': 'fecha_recepcion',
                  'Cierre': 'fecha_cierre',
                }.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key,
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                        Text('${detail![e.value] ?? 'Sin información'}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ExecutiveCard(
            title: 'Descripción',
            child: Text('${detail!['descripcion'] ?? 'Sin descripción'}'),
          ),
          ExecutiveCard(
            title: 'Observaciones',
            child: Text(
              '${detail!['observaciones'] ?? 'Sin observaciones registradas.'}',
            ),
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (screen == 'profile') return profile();
    if (screen == 'detail') return detailView();
    if (screen == 'new') {
      return NewRequestScreen(
        api: widget.api,
        catalogs: catalogs ?? {},
        entity: '${widget.user['entidad']}',
        onBack: back,
        onSaved: (folio) {
          setState(() {
            screen = 'dashboard';
            message = 'Solicitud registrada. Folio: $folio';
            filters.clear();
            page = 0;
          });
          load();
        },
      );
    }
    final hasData = summary != null && (summary!['total'] as num) > 0;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Panel ejecutivo · ${widget.user['entidad']}',
                            style: const TextStyle(fontSize: 12, color: muted),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Solicitudes registradas',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mi perfil',
                      onPressed: () => setState(() => screen = 'profile'),
                      icon: const Icon(Icons.person_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: catalogs == null || loading
                      ? null
                      : () => setState(() => screen = 'new'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva solicitud'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ámbito estatal',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: catalogs == null
                          ? null
                          : () => setState(() => showFilters = !showFilters),
                      icon: const Icon(Icons.tune, size: 16),
                      label: Text(
                        'Filtros ${filters.isEmpty ? '' : filters.length}',
                      ),
                    ),
                  ],
                ),
                if (showFilters && catalogs != null) filterPanel(),
                if (filters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: filters.entries
                          .map(
                            (e) => InputChip(
                              label: Text(
                                filterLabel(e.key, e.value),
                                style: const TextStyle(fontSize: 11),
                              ),
                              onDeleted: loading
                                  ? null
                                  : () => filter(e.key, null),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (message != null) Notice(message!),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (error != null) ...[
                  Notice(error!, error: true),
                  OutlinedButton.icon(
                    onPressed: load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ] else if (summary != null) ...[
                  ExecutiveCard(
                    title: 'Solicitudes registradas',
                    source: 'Cantidad de solicitudes del estado asignado que cumplen los filtros. No representa personas únicas ni apoyos entregados.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${summary!['total']}',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: salud,
                          ),
                        ),
                        const Text(
                          'Total según los filtros seleccionados',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${summary!['activas']} activas · ${summary!['resueltas']} resueltas',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                  if (!hasData)
                    ExecutiveCard(
                      title: filters.isEmpty
                          ? 'Aún no hay solicitudes'
                          : 'Sin resultados',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.inbox_outlined,
                            size: 46,
                            color: muted,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            filters.isEmpty
                                ? 'Las solicitudes de tu estado aparecerán aquí cuando se registren.'
                                : 'No hay solicitudes que coincidan con los filtros seleccionados.',
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: filters.isEmpty
                                ? () => setState(() => screen = 'new')
                                : clear,
                            child: Text(
                              filters.isEmpty
                                  ? 'Registrar primera solicitud'
                                  : 'Limpiar filtros',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ExecutiveCard(
                    title: 'Solicitudes recibidas vs. resueltas',
                    source: 'Últimos 12 meses. Recibidas por fecha de recepción y resueltas por fecha de cierre, usando los estatus de la base de datos. El periodo del filtro delimita la fecha de recepción de las solicitudes.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading('TENDENCIA · ÚLTIMOS 12 MESES'),
                        TrendChart(points: group('tendencia')),
                      ],
                    ),
                  ),
                  if ('${widget.user['clave_inegi']}' == '19')
                    ExecutiveCard(
                      title: 'Solicitudes realizadas',
                      source: 'Conteos por región del municipio de la solicitud, o del domicilio del beneficiario cuando no se especifica municipio. Los registros sin región se conservan como Sin información.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          heading('REGIÓN · TOCA PARA FILTRAR'),
                          RegionMap(
                            rows: group('regiones'),
                            active: filters['region_id'],
                            onSelect: (v) =>
                                filter('region_id', v, toggle: true),
                          ),
                        ],
                      ),
                    ),
                  bars(
                    'Solicitudes por municipio',
                    'municipios',
                    'municipio_id',
                    'Solicitudes agrupadas por municipio. Toca una barra para aplicar el filtro.',
                  ),
                  bars(
                    'Tipos de apoyo más solicitados',
                    'apoyos',
                    'tipo_apoyo_id',
                    'Solicitudes agrupadas por el tipo de apoyo registrado.',
                  ),
                  bars(
                    'Solicitudes por grupo vulnerable',
                    'grupos',
                    'grupo_vulnerable_id',
                    'Solicitudes agrupadas por el grupo del beneficiario. Un beneficiario puede tener varias solicitudes.',
                  ),
                  ExecutiveCard(
                    title: 'Resumen por dependencia',
                    source: 'Porcentaje de las solicitudes filtradas que corresponde a cada dependencia.',
                    child: group('dependencias').isEmpty
                        ? const Text(
                            'Sin datos por dependencia.',
                            style: TextStyle(color: muted),
                          )
                        : Column(
                            children: group('dependencias')
                                .map(
                                  (r) => InkWell(
                                    onTap: r['id'] == null
                                        ? null
                                        : () => filter(
                                            'dependencia_id',
                                            '${r['id']}',
                                            toggle: true,
                                          ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${r['nombre']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${r['total']}  ·  ${hasData ? ((r['total'] as num) / (summary!['total'] as num) * 100).toStringAsFixed(1) : '0'}%',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  ExecutiveCard(
                    title: 'Detalle de solicitudes',
                    child: rows.isEmpty
                        ? const Text(
                            'No hay solicitudes para mostrar.',
                            style: TextStyle(color: muted),
                          )
                        : Column(
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 20,
                                  dataRowMaxHeight: 64,
                                  headingTextStyle: const TextStyle(
                                    fontFamily: 'Mulish',
                                    color: ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                  dataTextStyle: const TextStyle(
                                    fontFamily: 'Mulish',
                                    color: ink,
                                    fontSize: 11,
                                  ),
                                  columns:
                                      [
                                            'Folio',
                                            'Municipio',
                                            'Tipo de apoyo',
                                            'Dependencia',
                                            'Estatus',
                                          ]
                                          .map(
                                            (h) => DataColumn(label: Text(h)),
                                          )
                                          .toList(),
                                  rows: rows
                                      .map(
                                        (r) => DataRow(
                                          cells:
                                              [
                                                    'folio',
                                                    'municipio',
                                                    'tipo_apoyo',
                                                    'dependencia',
                                                    'estatus',
                                                  ]
                                                  .map(
                                                    (k) => DataCell(
                                                      Text('${r[k]}'),
                                                      onTap: () => openDetail(
                                                        r['solicitud_id']
                                                            as int,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Toca una solicitud para consultar el detalle.',
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    tooltip: 'Anterior',
                                    onPressed: page == 0
                                        ? null
                                        : () {
                                            page--;
                                            load();
                                          },
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  Text(
                                    '${page + 1} / ${(total / 10).ceil()}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  IconButton(
                                    tooltip: 'Siguiente',
                                    onPressed: (page + 1) * 10 >= total
                                        ? null
                                        : () {
                                            page++;
                                            load();
                                          },
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
          decoration: const BoxDecoration(
            color: paper,
            border: Border(top: BorderSide(color: border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                exporting ? 'Generando reporte…' : '↓  Exportar reporte',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!hasData && !loading && error == null)
                const Text(
                  'Disponible cuando haya solicitudes.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          !hasData || loading || exporting || error != null
                          ? null
                          : () => export('xlsx'),
                      child: const Text('Excel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          !hasData || loading || exporting || error != null
                          ? null
                          : () => export('pdf'),
                      child: const Text('PDF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
