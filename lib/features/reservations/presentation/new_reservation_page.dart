import 'package:flutter/material.dart';

class NewReservationPage extends StatelessWidget {
  const NewReservationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Nueva reserva',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0B2942),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Formulario base preparado para el flujo de alta del Hito 6.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF4E6071)),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                _FieldHint(
                  label: 'Huesped',
                  hint: 'Pendiente de implementacion',
                ),
                SizedBox(height: 12),
                _FieldHint(label: 'Fecha', hint: 'Pendiente de implementacion'),
                SizedBox(height: 12),
                _FieldHint(
                  label: 'Horario',
                  hint: 'Pendiente de implementacion',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldHint extends StatelessWidget {
  const _FieldHint({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF425466),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: const TextStyle(fontSize: 13, color: Color(0xFF68778B)),
        ),
      ],
    );
  }
}
