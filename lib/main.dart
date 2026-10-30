import 'package:flutter/widgets.dart';

import 'app/costanorte_app.dart';
import 'core/push/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final PushNotificationService pushNotificationService =
      await FirebasePushNotificationService.bootstrap();
  runApp(CostaNorteApp(pushNotificationService: pushNotificationService));
}
