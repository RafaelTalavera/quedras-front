import 'package:costanorte/core/feedback/app_share.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppShare.shareText usa canal nativo propio en Windows',
      (WidgetTester tester) async {
    const MethodChannel channel = MethodChannel('costanorte/share_text');
    MethodCall? capturedCall;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      capturedCall = call;
      return true;
    });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            pageContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final bool result = await AppShare.shareText(
      pageContext,
      text: 'Reserva de massagem',
      subject: 'Atendimento Maria',
      failureTitle: 'Falha',
      failureMessagePrefix: 'Nao foi possivel compartilhar',
    );

    expect(result, isTrue);
    expect(capturedCall, isNotNull);
    expect(capturedCall!.method, 'shareText');
    expect(capturedCall!.arguments, <String, Object?>{
      'text': 'Reserva de massagem',
      'subject': 'Atendimento Maria',
      'title': 'Atendimento Maria',
    });

    debugDefaultTargetPlatformOverride = null;
  });
}
