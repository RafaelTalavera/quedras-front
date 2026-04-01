import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'app_alerts.dart';

final class AppShare {
  static const MethodChannel _windowsShareTextChannel = MethodChannel(
    'costanorte/share_text',
  );

  static Future<bool> shareText(
    BuildContext context, {
    required String text,
    String? subject,
    required String failureTitle,
    required String failureMessagePrefix,
  }) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        await _windowsShareTextChannel.invokeMethod<void>('shareText', <String, Object?>{
          'text': text,
          'subject': subject,
          'title': subject,
        });
      } else {
        await SharePlus.instance.share(
          ShareParams(text: text, subject: subject),
        );
      }
      return true;
    } catch (error) {
      if (context.mounted) {
        await AppAlerts.error(
          context,
          title: failureTitle,
          message: '$failureMessagePrefix: $error',
        );
      }
      return false;
    }
  }

  static Future<bool> shareFiles(
    BuildContext context, {
    required List<String> filePaths,
    String? text,
    String? subject,
    required String failureTitle,
    required String failureMessagePrefix,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
          files: filePaths.map(XFile.new).toList(),
        ),
      );
      return true;
    } catch (error) {
      if (context.mounted) {
        await AppAlerts.error(
          context,
          title: failureTitle,
          message: '$failureMessagePrefix: $error',
        );
      }
      return false;
    }
  }
}
