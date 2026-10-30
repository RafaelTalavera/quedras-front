import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class FirebasePushConfig {
  static const bool enabled = bool.fromEnvironment('FIREBASE_ENABLED');
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const String androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const String iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const String storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const String iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
  );
  static const String webVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
  );

  static bool get supportedPlatform =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static bool get shouldInitialize => enabled && supportedPlatform;

  static FirebaseOptions get options {
    if (!enabled) {
      throw StateError('Firebase no esta habilitado.');
    }
    final String appId = kIsWeb
        ? webAppId
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => androidAppId,
            TargetPlatform.iOS => iosAppId,
            _ => '',
          };
    final List<String> missing = <String>[
      if (apiKey.isEmpty) 'FIREBASE_API_KEY',
      if (projectId.isEmpty) 'FIREBASE_PROJECT_ID',
      if (messagingSenderId.isEmpty) 'FIREBASE_MESSAGING_SENDER_ID',
      if (appId.isEmpty) _appIdVariable,
      if (kIsWeb && webVapidKey.isEmpty) 'FIREBASE_WEB_VAPID_KEY',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Configuracion Firebase incompleta: ${missing.join(', ')}',
      );
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
    );
  }

  static String get serviceWorkerScriptPath {
    final Uri uri = Uri(
      path: 'firebase-messaging-sw.js',
      queryParameters: <String, String>{
        'apiKey': apiKey,
        'appId': webAppId,
        'messagingSenderId': messagingSenderId,
        'projectId': projectId,
        if (authDomain.isNotEmpty) 'authDomain': authDomain,
        if (storageBucket.isNotEmpty) 'storageBucket': storageBucket,
      },
    );
    return uri.toString();
  }

  static String get _appIdVariable {
    if (kIsWeb) return 'FIREBASE_WEB_APP_ID';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'FIREBASE_ANDROID_APP_ID',
      TargetPlatform.iOS => 'FIREBASE_IOS_APP_ID',
      _ => 'FIREBASE_APP_ID',
    };
  }
}
