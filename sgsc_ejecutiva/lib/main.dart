import 'package:flutter/material.dart';

import 'services/api_service.dart';

void main() {
  runApp(const SgscApp());
}

class SgscApp extends StatelessWidget {
  const SgscApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SGSC Ejecutiva',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const ConnectionPage(),
    );
  }
}

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final ApiService api = ApiService();

  String fastApiStatus = 'Sin probar';
  String mysqlStatus = 'Sin probar';

  bool loading = false;

  Future<void> probarConexion() async {
    setState(() {
      loading = true;
      fastApiStatus = 'Probando...';
      mysqlStatus = 'Probando...';
    });

    try {
      final health = await api.health();

      setState(() {
        fastApiStatus = health['status']?.toString() ?? 'ok';
      });
    } catch (e) {
      setState(() {
        fastApiStatus = 'Error: $e';
      });
    }

    try {
      final db = await api.databaseHealth();

      setState(() {
        mysqlStatus = db['database']?.toString() ?? 'connected';
      });
    } catch (e) {
      setState(() {
        mysqlStatus = 'Error: $e';
      });
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SGSC Ejecutiva'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 500,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Flutter → FastAPI → MySQL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),

                    Text(
                      'FastAPI: $fastApiStatus',
                      style: const TextStyle(
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'MySQL: $mysqlStatus',
                      style: const TextStyle(
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 30),

                    FilledButton(
                      onPressed: loading ? null : probarConexion,
                      child: Text(
                        loading
                            ? 'Probando conexión...'
                            : 'Probar conexión',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}