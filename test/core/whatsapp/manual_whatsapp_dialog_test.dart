import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:costanorte/core/whatsapp/manual_whatsapp_dialog.dart';

void main() {
  testWidgets('mostra prévia e exige escolha explícita de canal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showManualWhatsappDialog(
              context,
              providerName: 'Prestador A',
              phoneNumber: '5548999998888',
              message: 'Aviso de teste',
            ),
            child: const Text('Preparar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Preparar'));
    await tester.pumpAndSettle();
    expect(find.text('Aviso de teste'), findsOneWidget);
    expect(find.text('WhatsApp Web'), findsOneWidget);
    expect(find.textContaining('O sistema apenas prepara'), findsOneWidget);
    expect(find.textContaining('cole com Ctrl+V'), findsOneWidget);
  });

  testWidgets('copia o aviso de ordem AA ao clicar em WhatsApp Web', (
    tester,
  ) async {
    const String message =
        'Ordem de manutencao Hotel Costa Norte\nTitulo: Revisão AA\nLocal: PB · R\$ 10';
    const MethodChannel launcher = MethodChannel(
      'plugins.flutter.io/url_launcher',
    );
    final List<String> launchedUrls = <String>[];
    final List<String> steps = <String>[];
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            steps.add('copy');
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (MethodCall call) async {
          if (call.method == 'launch') {
            steps.add('open');
            launchedUrls.add(
              (call.arguments as Map<Object?, Object?>)['url']! as String,
            );
            return true;
          }
          return false;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcher, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showManualWhatsappDialog(
              context,
              providerName: 'Prestador A',
              phoneNumber: '5548999998888',
              message: message,
            ),
            child: const Text('Preparar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Preparar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WhatsApp Web'));
    await tester.pumpAndSettle();

    expect(copiedText, message);
    expect(steps, <String>['copy', 'open']);
    expect(find.textContaining('Texto copiado'), findsOneWidget);
    expect(launchedUrls, hasLength(1));
    expect(Uri.parse(launchedUrls.single).queryParameters['text'], message);
  });

  test('normaliza número internacional y rechaza datos inválidos', () {
    expect(
      normalizeManualWhatsappNumber('+55 (48) 99999-8888'),
      '5548999998888',
    );
    expect(normalizeManualWhatsappNumber('abc'), isNull);
    expect(normalizeManualWhatsappNumber(null), isNull);
  });

  test('conserva destinatario, acentos y saltos en ambos canales', () {
    const String number = '5548999998888';
    const String message = 'Ordem de manutenção\nLocal: PB · R\$ 10';
    final web = manualWhatsappWebUri(number, message);
    final windows = manualWhatsappWindowsUri(number, message);
    expect(web.queryParameters['phone'], number);
    expect(windows.queryParameters['phone'], number);
    expect(web.queryParameters['text'], message);
    expect(windows.queryParameters['text'], message);
    expect(web.host, 'web.whatsapp.com');
    expect(windows.scheme, 'whatsapp');
  });
}
