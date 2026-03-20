final class PtBrErrorTranslator {
  static final RegExp _reservationNotFoundPattern = RegExp(
    r'^Reservation (\d+) not found$',
  );
  static final RegExp _massageBookingNotFoundPattern = RegExp(
    r'^Massage booking (\d+) not found$',
  );

  static String translate(String rawMessage) {
    final String message = rawMessage.trim();
    if (message.isEmpty) {
      return 'Ocorreu um erro inesperado.';
    }

    final RegExpMatch? reservationNotFoundMatch =
        _reservationNotFoundPattern.firstMatch(message);
    if (reservationNotFoundMatch != null) {
      return 'Reserva ${reservationNotFoundMatch.group(1)} n\u00e3o encontrada.';
    }

    final RegExpMatch? massageBookingNotFoundMatch =
        _massageBookingNotFoundPattern.firstMatch(message);
    if (massageBookingNotFoundMatch != null) {
      return 'Massagem ${massageBookingNotFoundMatch.group(1)} n\u00e3o encontrada.';
    }

    switch (message) {
      case 'Invalid username or password.':
        return 'Usu\u00e1rio ou senha inv\u00e1lidos.';
      case 'Invalid JWT token.':
        return 'Token de acesso inv\u00e1lido.';
      case 'Authentication is required to access this resource.':
        return 'Autentica\u00e7\u00e3o necess\u00e1ria para acessar este recurso.';
      case 'Completed reservations cannot be cancelled.':
        return 'Reservas conclu\u00eddas n\u00e3o podem ser canceladas.';
      case 'Cancelled reservations cannot be edited.':
        return 'Reservas canceladas n\u00e3o podem ser editadas.';
      case 'Completed reservations cannot be edited.':
        return 'Reservas conclu\u00eddas n\u00e3o podem ser editadas.';
      case 'Reservation overlaps with an existing booking.':
        return 'J\u00e1 existe uma reserva ativa para esse hor\u00e1rio.';
      case 'Reservation must be within operating hours 07:00 to 23:00.':
        return 'A reserva deve estar dentro do hor\u00e1rio de funcionamento, das 07:00 \u00e0s 23:00.';
      case 'Reservation duration must be 60, 90 or 120 minutes.':
        return 'A dura\u00e7\u00e3o da reserva deve ser de 60, 90 ou 120 minutos.';
      case 'Inactive massage providers cannot receive bookings.':
        return 'Prestadores inativos n\u00e3o podem receber agendamentos.';
      case 'Massage provider already has a booking for the selected date and time.':
        return 'Esse prestador j\u00e1 possui um atendimento para a data e hor\u00e1rio selecionados.';
      case 'Cancelled massage bookings cannot be edited.':
        return 'Atendimentos cancelados n\u00e3o podem ser editados.';
      case 'Cancelled massage bookings cannot be cancelled again.':
        return 'Esse atendimento j\u00e1 est\u00e1 cancelado.';
      case 'cancellationNotes is required':
        return 'Informe a observa\u00e7\u00e3o do cancelamento.';
      case 'paymentMethod is required when paid is true':
        return 'Informe o meio de pagamento quando o atendimento estiver marcado como pago.';
      case 'paymentDate is required when paid is true':
        return 'Informe a data do pagamento quando o atendimento estiver marcado como pago.';
      case 'Unexpected error':
        return 'Erro inesperado.';
      default:
        return message;
    }
  }
}
