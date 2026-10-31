import 'package:costanorte/features/laundry/domain/laundry_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deserializa enums y fuerza relavado a importe visible cero', () {
    final LaundryShipment shipment = LaundryShipment.fromJson(<String, dynamic>{
      'id': 25,
      'shipmentNumber': 'LAV-REWASH',
      'providerId': 1,
      'providerName': 'Aguas Claras',
      'kind': 'REWASH',
      'status': 'SENT',
      'sentAt': '2026-10-30T12:00:00Z',
      'version': 1,
      'totalQuantity': 2,
      'billableAmount': 99,
      'lines': <Object>[],
    });
    expect(shipment.kind, LaundryShipmentKind.rewash);
    expect(shipment.status, LaundryShipmentStatus.sent);
    expect(shipment.displayedBillableAmount, 0);
    expect(shipment.kind.label, 'RELAVAGEM · SEM CUSTO');
  });

  test('crea request de envío con fecha UTC y solo contrato permitido', () {
    final Map<String, dynamic> json = CreateLaundryShipmentRequest(
      providerId: 1,
      sentAt: DateTime.parse('2026-10-30T09:00:00-03:00'),
      notes: 'Mañana',
      lines: const <CreateLaundryShipmentLineRequest>[
        CreateLaundryShipmentLineRequest(itemId: 7, quantity: 20),
      ],
    ).toJson();
    expect(json, <String, dynamic>{
      'providerId': 1,
      'kind': 'STANDARD',
      'sentAt': '2026-10-30T12:00:00.000Z',
      'notes': 'Mañana',
      'lines': <Object>[
        <String, dynamic>{'itemId': 7, 'quantity': 20.0, 'rewashReason': null},
      ],
    });
    expect(json['kind'], 'STANDARD');
    expect(json.containsKey('price'), isFalse);
  });

  group('validación de recepción', () {
    test('acepta recepción parcial', () {
      const ReceiveLaundryLineRequest request = ReceiveLaundryLineRequest(
        lineId: 1,
        acceptedQuantity: 3,
        rewashQuantity: 0,
        missingQuantity: 0,
        damagedQuantity: 0,
      );
      expect(request.validate(10), isNull);
    });
    test('rechaza exceso y exige motivo de relavado', () {
      const ReceiveLaundryLineRequest excessive = ReceiveLaundryLineRequest(
        lineId: 1,
        acceptedQuantity: 11,
        rewashQuantity: 0,
        missingQuantity: 0,
        damagedQuantity: 0,
      );
      const ReceiveLaundryLineRequest withoutReason = ReceiveLaundryLineRequest(
        lineId: 1,
        acceptedQuantity: 0,
        rewashQuantity: 1,
        missingQuantity: 0,
        damagedQuantity: 0,
      );
      expect(excessive.validate(10), contains('supera'));
      expect(withoutReason.validate(10), contains('motivo'));
      expect(withoutReason.toJson()['rewashReason'], isNull);
    });
  });

  test('deserializa relavado pendiente sin fecha de envío', () {
    final LaundryShipment shipment = LaundryShipment.fromJson(<String, dynamic>{
      'id': 3,
      'shipmentNumber': 'LAV-R3',
      'providerId': 1,
      'providerName': 'Aguas Claras',
      'kind': 'REWASH',
      'status': 'PENDING_DISPATCH',
      'sentAt': null,
      'version': 0,
      'totalQuantity': 2,
      'billableAmount': 0,
      'lines': <Object>[],
    });
    expect(shipment.isPendingDispatch, isTrue);
    expect(shipment.sentAt, isNull);
  });

  test('serializa confirmación de envío con versión y fecha UTC', () {
    final Map<String, dynamic> json = DispatchLaundryShipmentRequest(
      sentAt: DateTime.parse('2026-10-30T18:00:00-03:00'),
      version: 4,
      notes: 'Retiro tarde',
    ).toJson();
    expect(json['sentAt'], '2026-10-30T21:00:00.000Z');
    expect(json['version'], 4);
    expect(json['notes'], 'Retiro tarde');
  });
}
