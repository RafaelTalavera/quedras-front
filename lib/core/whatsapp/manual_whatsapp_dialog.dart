import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Prepares a conversation. Only the operator can send the message in WhatsApp.
Future<void> showManualWhatsappDialog(
  BuildContext context, {
  required String providerName,
  required String? phoneNumber,
  required String message,
}) async {
  final String? number = normalizeManualWhatsappNumber(phoneNumber);
  if (number == null) {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('WhatsApp indisponível'),
        content: const Text(
          'Cadastre um número de WhatsApp internacional válido para este prestador.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (BuildContext context) => _ManualWhatsappDialog(
      providerName: providerName,
      number: number,
      message: message,
    ),
  );
}

String? normalizeManualWhatsappNumber(String? value) {
  final String raw = (value ?? '').trim();
  if (raw.isEmpty) return null;
  final String digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 10 && digits.length <= 15 ? digits : null;
}

Uri manualWhatsappWebUri(String number, String message) => Uri.https(
  'web.whatsapp.com',
  '/send',
  <String, String>{'phone': number, 'text': message},
);

Uri manualWhatsappWindowsUri(String number, String message) => Uri(
  scheme: 'whatsapp',
  host: 'send',
  queryParameters: <String, String>{'phone': number, 'text': message},
);

class _ManualWhatsappDialog extends StatefulWidget {
  const _ManualWhatsappDialog({
    required this.providerName,
    required this.number,
    required this.message,
  });

  final String providerName;
  final String number;
  final String message;

  @override
  State<_ManualWhatsappDialog> createState() => _ManualWhatsappDialogState();
}

class _ManualWhatsappDialogState extends State<_ManualWhatsappDialog> {
  bool _opening = false;
  String? _feedback;

  Future<void> _open(Uri uri, {required String channel}) async {
    setState(() {
      _opening = true;
      _feedback = null;
    });
    bool copied = false;
    try {
      await Clipboard.setData(ClipboardData(text: widget.message));
      copied = true;
    } catch (_) {
      // The chat can still be opened if browser clipboard permissions fail.
    }
    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      setState(() {
        _feedback = opened
            ? copied
                  ? '$channel aberto. Texto copiado: se não aparecer na conversa, cole com Ctrl+V. Confira o destinatário antes de enviar.'
                  : '$channel aberto, mas não foi possível copiar o texto. Use o botão Copiar texto e confira o destinatário antes de enviar.'
            : copied
            ? 'Texto copiado, mas não foi possível abrir $channel. Abra o WhatsApp e cole com Ctrl+V.'
            : 'Não foi possível abrir $channel nem copiar o texto. Tente novamente ou selecione a mensagem para copiá-la.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedback = copied
            ? 'Texto copiado, mas não foi possível abrir $channel. Abra o WhatsApp e cole com Ctrl+V.'
            : 'Não foi possível abrir $channel nem copiar o texto. Tente novamente ou selecione a mensagem para copiá-la.';
      });
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.message));
      if (mounted) {
        setState(() {
          _feedback =
              'Texto copiado. Cole com Ctrl+V e confira o número antes de enviar.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedback =
              'Não foi possível copiar automaticamente. Selecione a mensagem para copiá-la.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool windows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    return AlertDialog(
      title: const Text('Preparar aviso por WhatsApp'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Prestador: ${widget.providerName}'),
              Text('Número: +${widget.number}'),
              const SizedBox(height: 12),
              const Text(
                'O sistema apenas prepara a conversa. O envio precisa ser confirmado dentro do WhatsApp.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Ao abrir o WhatsApp, o texto também é copiado. Se a mensagem não aparecer, cole com Ctrl+V na conversa.',
              ),
              const SizedBox(height: 12),
              SelectableText(widget.message),
              if (_feedback != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(_feedback!),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _opening ? null : _copy,
          child: const Text('Copiar texto'),
        ),
        if (windows)
          OutlinedButton(
            onPressed: _opening
                ? null
                : () => _open(
                    manualWhatsappWindowsUri(widget.number, widget.message),
                    channel: 'WhatsApp para Windows',
                  ),
            child: const Text('Aplicativo Windows'),
          ),
        FilledButton(
          onPressed: _opening
              ? null
              : () => _open(
                  manualWhatsappWebUri(widget.number, widget.message),
                  channel: 'WhatsApp Web',
                ),
          child: const Text('WhatsApp Web'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
