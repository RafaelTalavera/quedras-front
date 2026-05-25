import 'package:flutter/material.dart';

import '../theme/costa_norte_brand.dart';
import '../widgets/app_dialog_dimensions.dart';
import '../widgets/app_dialog_shell.dart';
import 'audit_models.dart';

Future<void> showAuditTimelineDialog({
  required BuildContext context,
  required String title,
  required List<AuditEventModel> events,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AppDialogShell(
        maxWidth: AppDialogDimensions.standardFormWidth,
        maxHeight: MediaQuery.of(dialogContext).size.height * 0.84,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(dialogContext).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Cambios registrados con fecha, usuario y detalle.',
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Flexible(
              child: events.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Aun no hay eventos de auditoria.'),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (BuildContext context, int index) {
                        final AuditEventModel event = events[index];
                        return _AuditEventCard(event: event);
                      },
                    ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _AuditEventCard extends StatelessWidget {
  const _AuditEventCard({required this.event});

  final AuditEventModel event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CostaNorteBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: CostaNorteBrand.foam,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _actionLabel(event.actionName),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: CostaNorteBrand.royalBlueDeep,
                  ),
                ),
              ),
              Text(
                _formatDateTime(event.occurredAt),
                style: const TextStyle(color: CostaNorteBrand.mutedInk),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            event.summaryText ?? event.actionName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: CostaNorteBrand.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Usuario: ${event.actorUsername ?? 'sistema'}${event.actorRole == null ? '' : ' (${event.actorRole})'}',
            style: const TextStyle(color: CostaNorteBrand.mutedInk),
          ),
          if (event.changes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            ...event.changes.map(
              (AuditFieldChange change) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_fieldLabel(change.field)}: ${_displayValue(change.before)} -> ${_displayValue(change.after)}',
                  style: const TextStyle(color: CostaNorteBrand.ink),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _actionLabel(String actionName) {
    switch (actionName.trim().toUpperCase()) {
      case 'CREATED':
        return 'Creacion';
      case 'UPDATED':
        return 'Actualizacion';
      case 'CANCELLED':
        return 'Cancelacion';
      default:
        return actionName;
    }
  }

  static String _fieldLabel(String field) {
    switch (field) {
      case 'guestName':
        return 'Responsable';
      case 'reservationDate':
        return 'Fecha';
      case 'startTime':
        return 'Inicio';
      case 'endTime':
        return 'Fin';
      case 'status':
        return 'Estado';
      case 'notes':
        return 'Observaciones';
      default:
        return field;
    }
  }

  static String _displayValue(Object? value) {
    if (value == null) {
      return '-';
    }
    final String raw = value.toString().trim();
    return raw.isEmpty ? '-' : raw;
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final DateTime local = value.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }
}
