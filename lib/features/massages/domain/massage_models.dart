import 'package:flutter/material.dart';

class MassageProvider {
  const MassageProvider({
    required this.id,
    required this.name,
    required this.specialty,
    required this.contact,
    this.active = true,
  });

  final String id;
  final String name;
  final String specialty;
  final String contact;
  final bool active;

  MassageProvider copyWith({
    String? id,
    String? name,
    String? specialty,
    String? contact,
    bool? active,
  }) {
    return MassageProvider(
      id: id ?? this.id,
      name: name ?? this.name,
      specialty: specialty ?? this.specialty,
      contact: contact ?? this.contact,
      active: active ?? this.active,
    );
  }
}

class MassageBooking {
  const MassageBooking({
    required this.id,
    required this.startAt,
    required this.clientName,
    required this.guestOrExternal,
    required this.treatment,
    required this.amount,
    required this.providerId,
    required this.paid,
  });

  final String id;
  final DateTime startAt;
  final String clientName;
  final String guestOrExternal;
  final String treatment;
  final double amount;
  final String providerId;
  final bool paid;
}

final class MassageCatalog {
  static const int agendaYear = 2026;

  static const List<String> monthLabels = <String>[
    'Janeiro',
    'Fevereiro',
    'Marco',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  static const List<String> weekDayLabels = <String>[
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sab',
    'Dom',
  ];

  static const List<String> treatmentTypes = <String>[
    'Relaxante',
    'Drenagem corporal',
    'Pedras quentes',
    'Terapeutica',
    'Banho',
    'Experiencia dupla',
  ];

  static List<MassageProvider> seededProviders() {
    return const <MassageProvider>[
      MassageProvider(
        id: 'david',
        name: 'David',
        specialty: 'Relaxante e casal',
        contact: '98804-3392',
      ),
      MassageProvider(
        id: 'danuska',
        name: 'Danuska',
        specialty: 'Drenagem e relaxante',
        contact: 'Agenda interna',
      ),
      MassageProvider(
        id: 'isabelita',
        name: 'Isabelita',
        specialty: 'Pedras quentes e terapeutica',
        contact: 'Agenda interna',
      ),
      MassageProvider(
        id: 'juliana',
        name: 'Juliana',
        specialty: 'Relaxante premium',
        contact: 'Agenda interna',
      ),
    ];
  }

  static List<MassageBooking> seededBookings() {
    return <MassageBooking>[
      _booking(
        id: 'jan-02-cacilda',
        month: 1,
        day: 2,
        hour: 17,
        client: 'Cacilda',
        guestOrExternal: 'Apto 405',
        treatment: 'Relaxante',
        amount: 200,
        providerId: 'david',
      ),
      _booking(
        id: 'jan-04-sonia',
        month: 1,
        day: 4,
        hour: 18,
        client: 'Sonia',
        guestOrExternal: 'Apto 407',
        treatment: 'Drenagem corporal',
        amount: 200,
        providerId: 'danuska',
      ),
      _booking(
        id: 'jan-06-andriele',
        month: 1,
        day: 6,
        hour: 17,
        client: 'Andriele',
        guestOrExternal: 'Externo',
        treatment: 'Relaxante',
        amount: 200,
        providerId: 'danuska',
      ),
      _booking(
        id: 'feb-07-rosa',
        month: 2,
        day: 7,
        hour: 18,
        client: 'Rosa',
        guestOrExternal: 'Apto 211',
        treatment: 'Relaxante',
        amount: 200,
        providerId: 'david',
      ),
      _booking(
        id: 'feb-10-fabian',
        month: 2,
        day: 10,
        hour: 17,
        client: 'Fabian',
        guestOrExternal: 'Externo',
        treatment: 'Relaxante',
        amount: 200,
        providerId: 'david',
      ),
      _booking(
        id: 'mar-05-marilene',
        month: 3,
        day: 5,
        hour: 20,
        client: 'Marilene chale 04',
        guestOrExternal: 'Chale 04',
        treatment: 'Relaxante',
        amount: 200,
        providerId: 'juliana',
      ),
      _booking(
        id: 'mar-06-rodrigo',
        month: 3,
        day: 6,
        hour: 10,
        client: 'Rodrigo',
        guestOrExternal: 'Externo',
        treatment: 'Relaxante',
        amount: 200,
        providerId: 'isabelita',
      ),
      _booking(
        id: 'mar-06-carlos',
        month: 3,
        day: 6,
        hour: 17,
        client: 'Carlos',
        guestOrExternal: 'Apto 9',
        treatment: 'Relaxante',
        amount: 200,
        providerId: 'juliana',
        paid: false,
      ),
      _booking(
        id: 'mar-06-ignacio',
        month: 3,
        day: 6,
        hour: 11,
        client: 'Ignacio',
        guestOrExternal: 'Apto 11',
        treatment: 'Terapeutica',
        amount: 200,
        providerId: 'david',
      ),
      _booking(
        id: 'mar-06-alessandra',
        month: 3,
        day: 6,
        hour: 19,
        client: 'Alessandra',
        guestOrExternal: 'Apto 405',
        treatment: 'Relaxante',
        amount: 200,
        providerId: 'isabelita',
      ),
      _booking(
        id: 'mar-07-susana',
        month: 3,
        day: 7,
        hour: 12,
        client: 'Susana',
        guestOrExternal: 'Externo',
        treatment: 'Relaxante',
        amount: 200,
        providerId: 'isabelita',
      ),
      _booking(
        id: 'mar-08-silvana',
        month: 3,
        day: 8,
        hour: 18,
        client: 'Silvana',
        guestOrExternal: 'Apto 303',
        treatment: 'Pedras quentes',
        amount: 200,
        providerId: 'isabelita',
      ),
    ];
  }

  static Color providerColor(String providerId) {
    switch (providerId) {
      case 'david':
        return const Color(0xFFE8F0FF);
      case 'danuska':
        return const Color(0xFFFFF0D5);
      case 'isabelita':
        return const Color(0xFFFBE7EC);
      case 'juliana':
        return const Color(0xFFE8F7EE);
      default:
        return Colors.white;
    }
  }

  static MassageBooking _booking({
    required String id,
    required int month,
    required int day,
    required int hour,
    required String client,
    required String guestOrExternal,
    required String treatment,
    required double amount,
    required String providerId,
    bool paid = true,
  }) {
    return MassageBooking(
      id: id,
      startAt: DateTime(agendaYear, month, day, hour),
      clientName: client,
      guestOrExternal: guestOrExternal,
      treatment: treatment,
      amount: amount,
      providerId: providerId,
      paid: paid,
    );
  }
}
