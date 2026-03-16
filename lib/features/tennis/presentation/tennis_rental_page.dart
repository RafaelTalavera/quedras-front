import 'package:flutter/material.dart';

import '../../reservations/application/reservation_app_service.dart';
import '../../reservations/presentation/new_reservation_page.dart';
import '../../schedule/presentation/schedule_page.dart';

enum _TennisPanel { agenda, novaReserva }

class TennisRentalPage extends StatefulWidget {
  const TennisRentalPage({required this.reservationAppService, super.key});

  final ReservationAppService reservationAppService;

  @override
  State<TennisRentalPage> createState() => _TennisRentalPageState();
}

class _TennisRentalPageState extends State<TennisRentalPage> {
  _TennisPanel _selectedPanel = _TennisPanel.agenda;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF0D3945),
                Color(0xFF18777F),
                Color(0xFFE0B36A),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                child: const Text(
                  'Operação ativa',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Aluguel de Quadras de Tênis',
                style: textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'O módulo concentra agenda diária, criação de reservas, edição e cancelamento sem abrir uma segunda tela de navegação.',
                style: TextStyle(
                  color: Color(0xFFF7F8FA),
                  height: 1.5,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 18),
              SegmentedButton<_TennisPanel>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<_TennisPanel>>[
                  ButtonSegment<_TennisPanel>(
                    value: _TennisPanel.agenda,
                    icon: Icon(Icons.event_note_rounded),
                    label: Text('Agenda'),
                  ),
                  ButtonSegment<_TennisPanel>(
                    value: _TennisPanel.novaReserva,
                    icon: Icon(Icons.add_circle_outline_rounded),
                    label: Text('Nova reserva'),
                  ),
                ],
                selected: <_TennisPanel>{_selectedPanel},
                onSelectionChanged: (Set<_TennisPanel> value) {
                  setState(() {
                    _selectedPanel = value.first;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey<_TennisPanel>(_selectedPanel),
            child: _selectedPanel == _TennisPanel.agenda
                ? SchedulePage(
                    reservationAppService: widget.reservationAppService,
                  )
                : NewReservationPage(
                    reservationAppService: widget.reservationAppService,
                  ),
          ),
        ),
      ],
    );
  }
}
