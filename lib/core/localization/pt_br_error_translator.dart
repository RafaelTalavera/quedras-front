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

    final RegExpMatch? reservationNotFoundMatch = _reservationNotFoundPattern
        .firstMatch(message);
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
      case 'The current role is not allowed to access this resource.':
        return 'Seu perfil atual nao possui permissao para acessar este recurso.';
      case 'A user with that username already exists.':
        return 'Ja existe um usuario com esse nome de acesso.';
      case 'Current password is invalid.':
        return 'A senha atual informada nao confere.';
      case 'New password must be different from the current password.':
        return 'A nova senha precisa ser diferente da senha atual.';
      case 'At least one enabled supervisor must remain in the system.':
        return 'O sistema precisa manter pelo menos um supervisor ativo.';
      case 'You cannot disable your own account.':
        return 'Nao e permitido bloquear a propria conta.';
      case 'You cannot change your own role.':
        return 'Nao e permitido alterar o proprio perfil por esta tela.';
      case 'User not found.':
        return 'Usuario nao encontrado.';
      case 'password is required':
        return 'Informe a senha.';
      case 'password must be at least 12 characters long':
        return 'A senha deve ter no minimo 12 caracteres.';
      case 'password must be <= 72 UTF-8 bytes':
        return 'A senha excede o tamanho maximo suportado.';
      case 'Completed reservations cannot be cancelled.':
        return 'Reservas conclu\u00eddas n\u00e3o podem ser canceladas.';
      case 'Cancelled reservations cannot be edited.':
        return 'Reservas canceladas n\u00e3o podem ser editadas.';
      case 'Completed reservations cannot be edited.':
        return 'Reservas conclu\u00eddas n\u00e3o podem ser editadas.';
      case 'Reservation overlaps with an existing booking.':
        return 'J\u00e1 existe uma reserva ativa para esse hor\u00e1rio.';
      case 'Court booking overlaps with an existing active booking.':
        return 'Ja existe uma reserva ativa para esse horario da quadra.';
      case 'Recurring court bookings are only available for partner coaches.':
        return 'Reservas recorrentes de quadra estao disponiveis apenas para professores parceiros.';
      case 'Recurring booking end date is required.':
        return 'Informe a data final da recorrencia.';
      case 'Recurring booking end date must be on or after the first booking date.':
        return 'A data final da recorrencia deve ser igual ou posterior a primeira reserva.';
      case 'Only recurring court bookings can be cancelled as a series.':
        return 'Somente reservas recorrentes podem ser canceladas como serie.';
      case 'Partner coach name must match an active predefined coach.':
        return 'Selecione um professor parceiro ativo previamente cadastrado.';
      case 'Court partner coach name already exists.':
        return 'Ja existe um professor parceiro com esse nome.';
      case 'Reservation must be within operating hours 07:00 to 23:00.':
        return 'A reserva deve estar dentro do hor\u00e1rio de funcionamento, das 07:00 \u00e0s 23:00.';
      case 'Reservation duration must be 60, 90 or 120 minutes.':
        return 'A dura\u00e7\u00e3o da reserva deve ser de 60, 90 ou 120 minutos.';
      case 'Inactive massage providers cannot receive bookings.':
        return 'Prestadores inativos n\u00e3o podem receber agendamentos.';
      case 'Massage provider already has a booking for the selected date and time.':
        return 'Esse prestador j\u00e1 possui um atendimento para a data e hor\u00e1rio selecionados.';
      case 'Inactive massage therapists cannot receive bookings.':
        return 'Masajistas inativos n\u00e3o podem receber agendamentos.';
      case 'Massage therapist already has a booking for the selected date and time.':
        return 'Esse masajista j\u00e1 possui um atendimento para a data e hor\u00e1rio selecionados.';
      case 'Massage therapist name already exists for provider.':
        return 'J\u00e1 existe um masajista com esse nome para o prestador selecionado.';
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
      case 'Request body is invalid or uses unsupported character encoding.':
        return 'O corpo da requisicao e invalido ou usa codificacao de caracteres nao suportada.';
      case 'Unexpected error':
        return 'Erro inesperado.';
      default:
        return message;
    }
  }
}
