import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'app_alerts.dart';

final class AppShare {
  static Future<bool> shareText(
    BuildContext context, {
    required String text,
    String? subject,
    required String failureTitle,
    required String failureMessagePrefix,
  }) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
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
