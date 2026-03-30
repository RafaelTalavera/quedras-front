import 'dart:convert';
import 'dart:io';

import 'package:costanorte/core/network/local_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LocalHttpClient envia JSON em UTF-8 para caracteres nao ASCII', () async {
    final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final List<int> capturedBodyBytes = <int>[];
    String? capturedContentType;

    final Future<void> requestHandled = () async {
      final HttpRequest request = await server.first;
      capturedContentType = request.headers.contentType?.toString();
      capturedBodyBytes.addAll(await request.fold<List<int>>(
        <int>[],
        (List<int> previous, List<int> element) => previous..addAll(element),
      ));
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.json
        ..write('{"message":"Invalid username or password."}');
      await request.response.close();
    }();

    final LocalHttpClient client = LocalHttpClient(
      baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
    );

    final String payload = jsonEncode(<String, String>{
      'username': 'operador.demo',
      'password': 'costanorte2026ª',
    });

    final response = await client.post(
      'auth/login',
      headers: const <String, String>{
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
      },
      body: payload,
    );

    await requestHandled;
    await server.close(force: true);

    expect(response.statusCode, 401);
    expect(utf8.decode(capturedBodyBytes), payload);
    expect(capturedContentType, contains('application/json'));
    expect(capturedContentType, contains('charset=utf-8'));
  });
}
