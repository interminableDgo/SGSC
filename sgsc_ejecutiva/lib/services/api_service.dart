import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';

class ApiService {
  Future<Map<String, dynamic>> health() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/health');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al conectar con FastAPI: ${response.statusCode}',
      );
    }

    return jsonDecode(response.body)
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> databaseHealth() async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/health/db',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al conectar con MySQL: ${response.statusCode}',
      );
    }

    return jsonDecode(response.body)
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> dashboardResumen() async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/dashboard/resumen',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al cargar dashboard: ${response.statusCode}',
      );
    }

    return jsonDecode(response.body)
        as Map<String, dynamic>;
  }
}