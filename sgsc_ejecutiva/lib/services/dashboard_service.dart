import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/filtros_dashboard.dart';

class DashboardService {
  Future<Map<String, dynamic>> obtenerResumen(
    FiltrosDashboard filtros,
  ) async {
    final query = <String, String>{};

    if (filtros.fechaInicio != null) {
      query['fecha_inicio'] =
          filtros.fechaInicio!
              .toIso8601String()
              .substring(0, 10);
    }

    if (filtros.fechaFin != null) {
      query['fecha_fin'] =
          filtros.fechaFin!
              .toIso8601String()
              .substring(0, 10);
    }

    if (filtros.municipioId != null) {
      query['municipio_id'] =
          filtros.municipioId.toString();
    }

    if (filtros.prioridadId != null) {
      query['prioridad_id'] =
          filtros.prioridadId.toString();
    }

    if (filtros.estatusId != null) {
      query['estatus_id'] =
          filtros.estatusId.toString();
    }

    if (filtros.tipoApoyoId != null) {
      query['tipo_apoyo_id'] =
          filtros.tipoApoyoId.toString();
    }

    if (filtros.dependenciaId != null) {
      query['dependencia_id'] =
          filtros.dependenciaId.toString();
    }

    if (filtros.canalRecepcionId != null) {
      query['canal_recepcion_id'] =
          filtros.canalRecepcionId.toString();
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/indicadores/resumen',
    ).replace(
      queryParameters:
          query.isEmpty ? null : query,
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al cargar indicadores: '
        '${response.statusCode}',
      );
    }

    return jsonDecode(response.body)
        as Map<String, dynamic>;
  }
}