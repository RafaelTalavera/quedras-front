import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/config/backend_config.dart';
import '../../../core/network/api_client.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = false;
  String _statusLabel = 'Pendiente de validacion';
  String _statusDetail =
      'Use el boton para verificar el estado del backend local.';

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Panel operativo del hotel',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0B2942),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cliente autenticado con JWT local para agenda y reservas protegidas por rol.',
          style: textTheme.bodyLarge?.copyWith(color: const Color(0xFF4E6071)),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            _InfoCard(
              title: 'Servidor API',
              value: _statusLabel,
              caption: _statusDetail,
              accentColor: _statusLabel == 'Disponible'
                  ? const Color(0xFF2B8A3E)
                  : const Color(0xFFBB3E03),
            ),
            const _InfoCard(
              title: 'Base URL',
              value: BackendConfig.apiBaseUrl,
              caption: 'Configurable via --dart-define=COSTANORTE_API_BASE_URL',
              accentColor: Color(0xFF13505B),
            ),
            const _InfoCard(
              title: 'Modulo actual',
              value: 'Hito 12 - Seguridad JWT',
              caption: 'Login, sesion y autorizacion con rol OPERATOR.',
              accentColor: Color(0xFF4A4E69),
            ),
            const _InfoCard(
              title: 'Seguridad activa',
              value: 'Bearer + rol',
              caption: 'Las reservas viajan autenticadas contra backend local.',
              accentColor: Color(0xFF167D85),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _loading ? null : _checkLocalBackend,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Icon(Icons.network_check_rounded),
          label: Text(_loading ? 'Validando...' : 'Verificar servidor local'),
        ),
      ],
    );
  }

  Future<void> _checkLocalBackend() async {
    setState(() {
      _loading = true;
    });

    try {
      final ApiResponse response = await widget.apiClient.get('system/health');
      if (!mounted) {
        return;
      }

      if (!response.isSuccess) {
        setState(() {
          _statusLabel = 'No disponible';
          _statusDetail =
              'HTTP ${response.statusCode}: backend no respondio OK.';
          _loading = false;
        });
        return;
      }

      final Map<String, dynamic>? payload = _tryParseMap(response.body);
      final String service = payload?['service']?.toString() ?? 'api-local';
      final String status = payload?['status']?.toString() ?? 'UP';
      final String environment =
          payload?['environment']?.toString() ?? 'indefinido';

      setState(() {
        _statusLabel = 'Disponible';
        _statusDetail = '$service | $status | entorno: $environment';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusLabel = 'No disponible';
        _statusDetail = 'Sin respuesta local: $error';
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? _tryParseMap(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.accentColor,
  });

  final String title;
  final String value;
  final String caption;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF516477),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                caption,
                style: const TextStyle(fontSize: 13, color: Color(0xFF526073)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
