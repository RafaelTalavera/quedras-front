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

  /* testWidgets('no Windows tenta o aplicativo antes de abrir o WhatsApp Web', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const MethodChannel launcher = MethodChannel(
      'plugins.flutter.io/url_launcher',
    );
    final List<String> launchedUrls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (MethodCall call) async {
          if (call.method == 'launch') {
            launchedUrls.add(
              (call.arguments as Map<Object?, Object?>)['url']! as String,
            );
            return launchedUrls.length == 2;
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
              message: 'Aviso de teste',
            ),
            child: const Text('Preparar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Preparar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir WhatsApp'));
    await tester.pumpAndSettle();

    expect(launchedUrls, hasLength(2));
    expect(Uri.parse(launchedUrls.first).scheme, 'whatsapp');
    expect(Uri.parse(launchedUrls.last).host, 'web.whatsapp.com');
    expect(
      find.textContaining('Aplicativo Windows indisponível'),
      findsOneWidget,
    );
  });

  ); */

  test('no Windows tenta o aplicativo antes de abrir o WhatsApp Web', () async {
    final List<Uri> opened = <Uri>[];
    final result = await openPreferredManualWhatsapp(
      desktopUri: manualWhatsappWindowsUri('5548999998888', 'Aviso'),
      webUri: manualWhatsappWebUri('5548999998888', 'Aviso'),
      open: (Uri uri) async {
        opened.add(uri);
        return opened.length == 2;
      },
    );

    expect(result, ManualWhatsappLaunchResult.web);
    expect(opened, hasLength(2));
    expect(opened.first.scheme, 'whatsapp');
    expect(opened.last.host, 'web.whatsapp.com');
  });

  testWidgets('mostra WhatsApp Web e copia sem numero configurado', (
    tester,
  ) async {
    const MethodChannel launcher = MethodChannel(
      'plugins.flutter.io/url_launcher',
    );
    final List<String> launchedUrls = <String>[];
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (MethodCall call) async {
          if (call.method == 'launch') {
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
              providerName: 'Equipe interna',
              phoneNumber: null,
              message: 'Ordem de manutenção interna',
            ),
            child: const Text('Preparar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Preparar'));
    await tester.pumpAndSettle();

    expect(find.text('Ordem de manutenção interna'), findsOneWidget);
    expect(find.textContaining('não configurado'), findsOneWidget);
    expect(find.text('Copiar texto'), findsOneWidget);
    expect(find.text('WhatsApp Web'), findsOneWidget);

    await tester.tap(find.text('WhatsApp Web'));
    await tester.pumpAndSettle();

    expect(copiedText, 'Ordem de manutenção interna');
    expect(launchedUrls, hasLength(1));
    final Uri uri = Uri.parse(launchedUrls.single);
    expect(uri.host, 'web.whatsapp.com');
    expect(uri.path, '/');
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

  test('abre canais sem destinatario para fluxo manual', () {
    final web = manualWhatsappWebUri(null, 'Aviso');
    final windows = manualWhatsappWindowsUri(null, 'Aviso');
    expect(web.host, 'web.whatsapp.com');
    expect(web.path, '/');
    expect(web.queryParameters, isEmpty);
    expect(windows.scheme, 'whatsapp');
    expect(windows.host, isEmpty);
  });
}
