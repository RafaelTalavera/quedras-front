final class PtBrErrorTranslator {
  static final RegExp _reservationNotFoundPattern = RegExp(
    r'^Reservation (\d+) not found$',
  );

  static String translate(String rawMessage) {
    final String message = rawMessage.trim();
    if (message.isEmpty) {
      return 'Ocorreu um erro inesperado.';
    }

    final RegExpMatch? reservationNotFoundMatch = _reservationNotFoundPattern
        .firstMatch(message);
    if (reservationNotFoundMatch != null) {
      return 'Reserva ${reservationNotFoundMatch.group(1)} não encontrada.';
    }

    switch (message) {
      case 'Invalid username or password.':
        return 'Usuário ou senha inválidos.';
      case 'Invalid JWT token.':
        return 'Token de acesso inválido.';
      case 'Authentication is required to access this resource.':
        return 'Autenticação necessária para acessar este recurso.';
      case 'Completed reservations cannot be cancelled.':
        return 'Reservas concluídas não podem ser canceladas.';
      case 'Cancelled reservations cannot be edited.':
        return 'Reservas canceladas não podem ser editadas.';
      case 'Completed reservations cannot be edited.':
        return 'Reservas concluídas não podem ser editadas.';
      case 'Reservation overlaps with an existing booking.':
        return 'Já existe uma reserva ativa para esse horário.';
      case 'Reservation must be within operating hours 07:00 to 23:00.':
        return 'A reserva deve estar dentro do horário de funcionamento, das 07:00 às 23:00.';
      case 'Reservation duration must be 60, 90 or 120 minutes.':
        return 'A duração da reserva deve ser de 60, 90 ou 120 minutos.';
      case 'Unexpected error':
        return 'Erro inesperado.';
      default:
        return message;
    }
  }
}
